class SalesController < ArtfullyOseController
  before_filter :find_event, :find_show, :find_people, :find_dummy
  before_filter :create_door_list, :only => ['show', 'new']

  def show
    redirect_to new_event_show_sales_path(@event, @show)
  end

  def new
    @person = Person.new
    @sale = Sale.new(@show, @show.chart.sections.box_office)
    @tickets_remaining = tickets_remaining
    setup_defaults
  end


  #
  # This needs a significant refactor.  There is no way to maintain the sale object
  # across requests.  Because of this the number of locked tickets proliferates.
  #
  # Refactor this to maintain the cart across requests and clear the cart on successful sale
  #
  # In the meantime, BoxOffice::Cart has been jenked to just not lock tickets.
  #
  def create
    @sale = Sale.new(@show, @show.chart.sections.box_office, params[:quantities])
    if checking_out?
      if @sale.sell(payment)
        @sale.message = "Sold #{self.class.helpers.pluralize(@sale.tickets.length, 'ticket')}.  Order total was #{self.class.helpers.number_as_cents @sale.cart.total}"
      end
    end

    unless @sale.errors.empty?
      @sale.error = "#{@sale.errors.full_messages.to_sentence.capitalize}."
      ExpireTicketJob.new(@sale.cart.tickets).perform
    end
    
    render :json => @sale.as_json
                         .merge(:total => @sale.cart.total)
                         .merge(:tickets_remaining => tickets_remaining)
                         .merge(:door_list_rows => door_list_rows), 
                         :status => 200
  end

  def checking_out?
    !params[:commit].blank?
  end
  
  def door_list_rows
    door_list_rows = []
    
    @sale.tickets.each_with_index do |ticket, i|
      ticket.reload
      if ticket.sold? || ticket.comped?
        door_list_rows[i] = {}
        door_list_rows[i]['first_name'] = @sale.buyer.first_name
        door_list_rows[i]['last_name'] = @sale.buyer.last_name
        door_list_rows[i]['email'] = @sale.buyer.email
        door_list_rows[i]['section'] = ticket.section.name
        door_list_rows[i]['payment_method'] = ticket.sold_item.order.payment_method
        door_list_rows[i]['price'] = ticket.sold_price
      end
    end
    door_list_rows
  end

  private
    def tickets_remaining
      remaining = {}
      @sale.sections.each do |section|
        remaining[section.id] = section.summary.available
      end
      remaining
    end
    
    def setup_defaults
      params[:anonymous]   = true
      params[:cash]        = true
      params[:credit_card] = {}
    end

    def find_event
      @event = Event.find(params[:event_id])
    end

    def find_show
      @show = Show.find(params[:show_id])
      authorize! :view, @show
    end

    def find_people
      if params[:terms].present?
        @people = Person.search_index(params[:terms].dup, current_user.current_organization)
      else
        @people = []
      end
    end

    def create_door_list
      @door_list = DoorList.new(@show)
    end

    def find_dummy
      @dummy = Person.dummy_for(current_user.current_organization)
    end

    def person
      params[:person_id].blank? ? @dummy : Person.find(params[:person_id])
    end

    def payment                    
      if Swiper.can_parse? params[:credit_card][:number]
        swiped_data = Swiper.parse(params[:credit_card][:number])
        params[:credit_card][:name] = swiped_data.track1.cardholder_name
        params[:credit_card][:number] = swiped_data.track1.primary_account_number
        params[:credit_card][:month] = swiped_data.track1.expiration_month
        params[:credit_card][:year] = swiped_data.track1.expiration_year
      end
      
      params[:benefactor] = current_user
      
      payment = Payment.create(params[:payment_method], params)
      payment.customer = person
      payment
    end
  
    def has_card_info?
      params[:credit_card].present? and params[:credit_card][:card_number].present?
    end

end
