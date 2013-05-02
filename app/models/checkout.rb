class Checkout
  include ActiveSupport::Callbacks
  define_callbacks :payment
  define_callbacks :order
  
  include Ext::Callbacks::Checkout
  
  attr_accessor :cart, :payment, :error
  attr_reader :order, :person

  def self.for(cart, payment)
    cart.checkout_class.new(cart, payment)
  end
  
  def message
    message = @error || @payment.errors.full_messages.to_sentence.downcase
    message = message.gsub('customer', 'contact info')
    message = message.gsub('credit card is', 'payment details are')
    message = message[0].upcase + message[1..message.length] unless message.blank? #capitalize first word
    
    if message.blank?
      message = "We had a problem validating your payment.  Wait a few moments and try again or contact us to complete your purchase."
    end
    
    message
  end

  def initialize(cart, payment)
    @cart = cart
    @payment = payment
    @customer = payment.customer
    @payment.amount = @cart.total
  end

  def valid?
    return false if cart.nil?

    if cart.empty?
      @error = "Your tickets have expired.  Please select your tickets again."
      return false
    end

    unless (!!cart and !!payment and payment.valid?)
      return false
    end
    
    true
  end

  def finish
    run_callbacks :payment do
      pay
    end
    
    if cart.approved?
      order_timestamp = Time.now
      
      run_callbacks :order do
        @created_orders = create_order(order_timestamp)
      end
      
      cart.finish
    end
    
    cart.approved?
  end
  
  def pay
    @cart.pay_with(@payment)
    @cart.approved?
  end

  private
    def create_sub_orders(order_timestamp)
      created_orders = []
      cart.organizations.each do |organization|
        @person = Person.find_or_create(@customer, organization)
        @person.update_address(Address.from_payment(payment), organization.time_zone, nil, "checkout")
        @person.add_phone_if_missing(payment.payment_phone_number)
        
        @order = new_order(organization, order_timestamp, @person)
        @order.save!

        #
        # This should be DJ'd
        #
        begin
          OrderMailer.confirmation_for(order).deliver unless @person.dummy? || @person.email.blank?
        rescue Exception => e
          Exceptional.context(:order_id => order.id)
          Exceptional.handle(e, "Could not send order confirmation for order")
        end

        created_orders << @order
      end
      
      created_orders
    end

    def create_order(order_timestamp)
      create_sub_orders(order_timestamp)
    end

    def order_class
      WebOrder
    end

    def new_order(organization, order_timestamp, person)
      order_class.new.tap do |order|
        order.organization                = organization
        order.created_at                  = order_timestamp
        order.person                      = @person
        order.transaction_id              = @payment.transaction_id
        order.service_fee                 = @cart.fee_in_cents
        order.special_instructions        = @cart.special_instructions
        order.payment_method              = @payment.payment_method
        order.per_item_processing_charge  = @payment.per_item_processing_charge

        order << @cart.tickets.select { |ticket| ticket.organization_id == organization.id }
        order << @cart.donations
      end
    end
end
