class EventsImport < Import
  include Imports::Rollback
  include Imports::Validations
  
  def kind
    "events"
  end
  
  def process(parsed_row)
    row_valid?(parsed_row)
    person      = create_person(parsed_row)
    event       = create_event(parsed_row, person)
    show        = create_show(parsed_row, event)
    chart       = create_chart(parsed_row, event, show)
    ticket      = create_ticket(parsed_row, person, event, show, chart)
    order       = create_order(parsed_row, person, event, show, ticket)
    actions     = create_actions(parsed_row, person, event, show, order)
  end
  
  def rollback_events
    Event.where(:import_id => self.id).all.each {|e| e.destroy}
  end
  
  def rollback 
    rollback_orders
    rollback_events
    rollback_people
  end
  
  def row_valid?(parsed_row)
    Rails.logger.info("Import #{id} EVENT_IMPORT: Validating Row")
    raise Import::RowError, "No Event Name included in this row: #{parsed_row.row}" unless parsed_row.event_name 
    raise Import::RowError, "No Show Date included in this row: #{parsed_row.row}" unless parsed_row.show_date
    raise Import::RowError, "Please include a payment method in this row: #{parsed_row.row}" if parsed_row.payment_method.blank?
    valid_date?   parsed_row.show_date    
    valid_amount? parsed_row.unparsed_amount      unless parsed_row.unparsed_amount.blank?
    valid_date?   parsed_row.order_date           unless parsed_row.order_date.blank?
    true
  end
  
  def create_person(parsed_row)
    if !attach_person(parsed_row).person_info
      person = self.organization.dummy
    elsif !parsed_row.email.blank?
      person = Person.first_or_create({:email => parsed_row.email, :organization => self.organization}.merge(parsed_row.person_attributes), {}) do |p|
        p.import = self
      end
    else    
      person = attach_person(parsed_row)
      if !person.save
        self.import_errors.create! :row_data => parsed_row.row, :error_message => person.errors.full_messages.join(", ")
        self.reload
        fail!
      end 
    end
    person  
  end
  
  def create_chart(parsed_row, event, show)
    Rails.logger.info("Import #{id} EVENT_IMPORT: Creating chart")
    chart = show.chart || show.create_chart({ :name => event.name, :skip_create_first_section => true })   
    Rails.logger.info("Import #{id} EVENT_IMPORT: Using chart:")
    Rails.logger.info("Import #{id} EVENT_IMPORT: #{chart.inspect}")
    amount = parsed_row.amount || 0
    Rails.logger.info("Import #{id} EVENT_IMPORT: Amount is [#{amount}]")
    section = chart.sections.where(:price => amount).first || chart.sections.build(:name => event.name,:price => amount, :capacity => 1)    
    Rails.logger.info("Import #{id} EVENT_IMPORT: Using section:")
    Rails.logger.info("Import #{id} EVENT_IMPORT: #{section.inspect}")
    Rails.logger.info("Import #{id} EVENT_IMPORT: Bumping section capacity")
    section.capacity = section.capacity + 1 unless section.new_record?
    Rails.logger.info("Import #{id} EVENT_IMPORT: Saving section")
    section.save
    Rails.logger.info("Import #{id} EVENT_IMPORT: #{section.inspect}")
    Rails.logger.info("Import #{id} EVENT_IMPORT: Saving chart")
    chart.save
    Rails.logger.info("Import #{id} EVENT_IMPORT: #{show.inspect}")
    saved = show.save(:validate => false)
    Rails.logger.info("Import #{id} EVENT_IMPORT: Show saved[#{saved}]")
    chart
  end

  def create_event(parsed_row, person)
    Rails.logger.info("Import #{id} EVENT_IMPORT: Creating event")
    event = Event.where(:name => parsed_row.event_name).where(:organization_id => self.organization).first
    return event if event
      
    event = Event.new
    event.name = parsed_row.event_name
    event.organization = self.organization
    event.venue = Venue.new
    event.venue.name = parsed_row.venue_name
    event.venue.organization = self.organization
    event.venue.time_zone = self.organization.time_zone
    event.contact_email = self.organization.email || self.user.email
    event.import = self
    event.save!
    Rails.logger.info("Import #{id} EVENT_IMPORT: Created event #{event.inspect}")
    unless event.charts.empty?
      Rails.logger.info("Import #{id} EVENT_IMPORT: Default event chart created #{event.charts.first.inspect}") 
    end
    event
  end
  
  def show_key(show_date, event_name)
    [show_date, event_name].join("-")
  end
  
  def existing_show(show_date, event_name)
    Rails.logger.info("Import #{id} EVENT_IMPORT: Checking existing show")
    @imported_shows ||= {}
    show = @imported_shows[show_key(show_date, event_name)]    
  end
  
  def eight_pm?(show_date)
    begin
      Time.parse(show_date.match(/[0-9]+\:[0-9][0-9][a|p]m?/).to_s)
    rescue ArgumentError
      show_date = show_date + " 8:00pm"
    end
    
    show_date
  end
  
  def new_show(parsed_row, event)
    Rails.logger.info("Import #{id} EVENT_IMPORT: Creating new show")
    show = Show.new
    show.datetime = time_zone_parser.parse(eight_pm?(parsed_row.show_date))
    show.event = event
    show.organization = self.organization
    show.state = "unpublished"                      #Hacky end-around state machine here because we don't have a chart yet
    show.save(:validate => false)
    Rails.logger.info("Import #{id} EVENT_IMPORT: Show saved #{show.inspect}")
    
    @imported_shows[show_key(parsed_row.show_date, event.name)] = show
    show    
  end
  
  def create_show(parsed_row, event)
    Rails.logger.info("Import #{id} EVENT_IMPORT: Creating show")
    return existing_show(parsed_row.show_date, event) || new_show(parsed_row, event)
  end
  
  def create_actions(parsed_row, person, event, show, order)
    Rails.logger.info("Import #{id} EVENT_IMPORT: Creating actions")
    go_action = GoAction.for(show, person)
    go_action.import = self
    go_action.save
     
    #get action is created by the order
    get_action = GetAction.where(:subject_id => order.id).first
    get_action.update_attribute(:occurred_at, time_zone_parser.parse(parsed_row.order_date)) unless parsed_row.order_date.blank?
    
    return go_action, get_action
  end
  
  def create_ticket(parsed_row, person, event, show, chart)
    Rails.logger.info("Import #{id} EVENT_IMPORT: Creating ticket")
    amount = parsed_row.amount || 0
    Rails.logger.info("Import #{id} EVENT_IMPORT: Amount is [#{amount}]")
    section = chart.sections.where(:price => amount).first
    Rails.logger.info("Import #{id} EVENT_IMPORT: Section is [#{section.inspect}]")
    
    raise Import::RuntimeError, 'No section found for ticket' unless section
    
    ticket = Ticket.build_one(show, section, section.price,1, true)
    Rails.logger.info("Import #{id} EVENT_IMPORT: Ticket built [#{ticket.inspect}]")
    ticket.sell_to person
    Rails.logger.info("Import #{id} EVENT_IMPORT: Ticket sold to [#{person.inspect}]")
    ticket.sold_price = amount
    ticket.save
    Rails.logger.info("Import #{id} EVENT_IMPORT: Ticket saved [#{ticket.inspect}]")
    ticket
  end
   
  def create_order(parsed_row, person, event, show, ticket)
    Rails.logger.info("Import #{id} EVENT_IMPORT: Creating order")
    order_key = [show.id.to_s,person.id.to_s,parsed_row.payment_method].join('-')
    @imported_orders ||= {}
    order = @imported_orders[order_key] || ImportedOrder.new
    order.organization = self.organization
    order.payment_method = parsed_row.payment_method
    order.person = person
    order.details = "Imported by #{user.email} on #{I18n.l self.created_at_local_to_organization, :format => :date}"
    order.import = self
    item = Item.for(ticket)
    item.state = "settled"
    order.items << item
    order.skip_actions = true
    order.save
    order.update_attribute(:created_at, time_zone_parser.parse(parsed_row.order_date)) unless parsed_row.order_date.blank?
    order.create_purchase_action_without_delay
    order.actions.where(:type => "GetAction").first.update_attribute(:occurred_at, parsed_row.order_date) unless parsed_row.order_date.blank?
    @imported_orders[order_key] = order
    order
  end
  
  def events_hash
    return @events if @events
    @events = {}
    parsed_rows.each do |row|
      key = (row.event_name || "") + (row.venue_name || "") + (row.show_date.to_s || "")
      @events[key] ||= []
      @events[key] << row
    end
    @events
  end
end