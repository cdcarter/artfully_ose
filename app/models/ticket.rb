class Ticket < ActiveRecord::Base
  include ActiveRecord::Transitions
  include Ext::Resellable::Ticket
  include Ext::Integrations::Ticket
  include Ticket::Pricing
  include Ticket::Transfers
  include Ticket::SaleTransitions
  extend ActionView::Helpers::TextHelper
  
  attr_accessible :section_id, :section, :price, :venue, :cart_price

  belongs_to :buyer, :class_name => "Person"
  belongs_to :show
  belongs_to :organization
  belongs_to :section
  belongs_to :cart
  belongs_to :discount
  
  has_many :items, :foreign_key => "product_id"

  delegate :event, :to => :show

  before_validation :set_cart_price

  def self.sold_after(datetime)
    sold.where("sold_at > ?", datetime)
  end

  def self.sold_before(datetime)
    sold.where("sold_at < ?", datetime)
  end

  scope :played,      lambda { joins(:show).merge(Show.played) }
  scope :unplayed,    lambda { joins(:show).merge(Show.unplayed) }
  scope :resellable,  lambda { where(:state => "on_sale") }

  state_machine do
    state :off_sale
    state :on_sale
    state :sold
    state :comped

    event(:on_sale)                                   { transitions :from => [ :on_sale, :off_sale ],   :to => :on_sale   }
    event(:off_sale)                                  { transitions :from => [ :on_sale, :off_sale ],   :to => :off_sale  }
    event(:exchange, :success => :record_exchange)    { transitions :from => [ :on_sale, :off_sale ],   :to => :sold      }
    event(:sell, :success => :record_sale)            { transitions :from => [ :on_sale ],              :to => :sold      }
    event(:comp, :success => :record_comp)            { transitions :from => [ :on_sale, :off_sale ],   :to => :comped    }
    event(:return_to_inventory)                       { transitions :from => [ :comped, :sold ],        :to => :on_sale   }
    event(:return_off_sale)                           { transitions :from => [ :comped, :sold ],        :to => :off_sale  }
  end

  def datetime
    show.datetime_local_to_event
  end

  def as_json(options = {})
    super(options).merge!({:section => section})
  end

  def self.unsold
    where(:state => [:off_sale, :on_sale])
  end

  def self.to_sentence(tickets)
    shows_string = tickets.map(&:show).uniq.length > 1 ? ", multiple shows" : " on " + I18n.localize(tickets.first.show.datetime_local_to_event, :format => :day_time_at)
    events_string = tickets.map(&:show).map(&:event).uniq.length > 1 ? "multiple events" : tickets.first.show.event.name + shows_string
    pluralize(tickets.length, "ticket") + " to " + events_string
  end

  def order_summary_description
    self.section.name
  end

  #
  # Unfortunately named.  This will return available tickets, not a count of available tickets
  # as is the idiom elsewhere in the app
  #
  def self.available(params = {}, limit = 4)
    conditions = params.dup
    conditions[:state] ||= :on_sale
    conditions[:cart_id] = nil
    where(conditions).limit(limit)
  end

  def settlement_id
    settled_item.settlement_id unless settled_item.nil?
  end

  def settled_item
    @settled_item ||= items.select(&:settled?).first
  end
  
  def sold_item
    items.select(&:purchased?).first ||
    items.select(&:settled?).first ||
    items.select(&:comped?).first
  end
  
  def special_instructions
    sold_item.nil? ? nil : sold_item.order.special_instructions
  end

  def self.fee
    0
  end

  def expired?
    datetime < DateTime.now
  end

  def refundable?
    sold?
  end

  def exchangeable?
    !expired? and sold?
  end

  def returnable?
    !expired?
  end

  def committed?
    sold? or comped?
  end

  def on_saleable?
    !(sold? or comped?)
  end

  def off_saleable?
    on_sale?
  end

  def destroyable?
    !sold? and !comped? and items.empty?
  end

  def compable?
    on_sale? or off_sale?
  end

  def resellable?
    on_sale?
  end

  def destroy
    super if destroyable?
  end

  def repriceable?
    not committed?
  end

  #Bulk creation of tickets should use this method to ensure all tickets are created the same
  #Reminder that this returns a ActiveRecord::Import::Result, not an array of tickets
  def self.create_many(show, section, quantity, on_sale = false)
    new_tickets = []
    quantity.times do
      new_tickets << build_one(show, section, section.price, quantity, on_sale)
    end
    
    result = Ticket.import(new_tickets)
    result
  end
  
  def self.build_one(show, section, price, quantity, on_sale = false)
    t = Ticket.new({
      :venue => show.event.venue.name,
      :price => price,
      :section => section,
    })
    t.show = show
    t.organization = show.organization
    t.state = 'on_sale' if on_sale
    t
  end
end
