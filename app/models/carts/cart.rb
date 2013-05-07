class Cart < ActiveRecord::Base
  include ActiveRecord::Transitions
  
  has_many :donations, :dependent => :destroy
  has_many :tickets, :after_add => :set_timeout
  after_destroy :clear!
  before_validation :set_token
  attr_accessor :special_instructions
  attr_accessible :token, :reseller_id

  validates :token,
            :presence => true,
            :length => { :is => 64 },
            :format => /\A[0-9a-f]+\z/i

  belongs_to :discount

  state_machine do
    state :started
    state :approved
    state :rejected

    event(:approve, :success => :record_sold_price) { transitions :from => [ :started, :rejected ], :to => :approved }
    event(:reject)  { transitions :from => [ :started, :rejected ], :to => :rejected }
  end

  delegate :empty?, :to => :items

  def items
    self.tickets + self.donations
  end
    
  def checkout_class
    Checkout
  end

  def clear!
    reset_prices_on_tickets
    clear_tickets
    clear_donations
  end
  
  def as_json(options = {})
    super({ :methods => [ 'tickets', 'donations' ]}.merge(options))
  end
  
  def clear_tickets
    release_tickets
    self.tickets = []
  end

  def release_tickets
    tickets.each { |ticket| ticket.remove_from_cart }
  end

  def set_timeout(ticket)
    save if new_record?
    
    if Delayed::Worker.delay_jobs
      Delayed::Job.enqueue(ExpireTicketJob.new(Array.wrap(ticket.id)), :run_at => 10.minutes.from_now, :queue => "ticket")
    end
  end

  def items_subject_to_fee
    self.tickets.reject{|t| t.price == 0}
  end

  def fee_in_cents
    items_subject_to_fee.size * (ARTFULLY_CONFIG[:ticket_fee] || 0)
  end

  def clear_donations
    temp = []

    #This won't work if there is more than 1 FAFS donation on the order
    donations.each do |donation|
      temp = donations.delete(donations)
    end
    temp
  end

  def <<(tkts)
    self.tickets << tkts
  end

  def subtotal
    items.sum(&:price)
  end

  def total_before_discount
    items.sum(&:price) + fee_in_cents
  end

  def total
    items.sum(&:cart_price) + fee_in_cents
  end

  def discount_amount
    total_before_discount - total
  end

  def unfinished?
    started? or rejected?
  end

  def completed?
    approved?
  end

  def pay_with(payment, options = {})
    @payment = payment

    #TODO: Move the requires_authorization? check into the payments classes.  Cart shouldn't care
    if payment.requires_authorization?
      options[:service_fee] = fee_in_cents
      pay_with_authorization(payment, options)
    else
      approve!
    end
  end

  def finish
  end

  def generate_donations
    organizations_from_tickets.collect do |organization|
      if organization.can?(:receive, Donation)
        donation = Donation.new
        donation.organization = organization
        donation
      end
    end.compact
  end

  def organizations
    (organizations_from_donations + organizations_from_tickets).uniq
  end

  def organizations_from_donations
    Organization.find(donations.collect(&:organization_id))
  end

  def organizations_from_tickets
    Organization.find(tickets.collect(&:organization_id))
  end

  def can_hold?(ticket)
    true
  end

  def self.create_for_reseller(reseller_id = nil, params = {})
    reseller_id.blank? ? Cart.create(params) : Reseller::Cart.create( params.merge({:reseller => Organization.find(reseller_id)}) )
  end
  
  def self.find_or_create(cart_token, reseller_id)
    if cart_token.nil?
      raise ActiveRecord::RecordNotFound.new("No cart with nil token")
    end

    if reseller_id.present?
      if Cart.find_by_token_and_reseller_id(cart_token, reseller_id)
        cart = Cart.find_by_token_and_reseller_id(cart_token, reseller_id)
      else
        cart = Reseller::Cart.create(token: cart_token, reseller_id: reseller_id)
      end
    else
      cart = Cart.find_or_create_by_token!(cart_token)
    end

    if cart.completed?
      cart.transfer_token_to_new_cart
    else
      cart
    end
  end

  def transfer_token_to_new_cart
    new_cart = Cart.new
    transaction do
      new_cart.type = self.type
      new_cart.reseller_id = self.reseller_id
      new_cart.token = self.token
      self.token = nil
      self.save!
      new_cart.save!
    end
    new_cart
  end

  def reseller_is?(reseller_id)
    (self.reseller_id.blank? && reseller_id.blank?) || (self.reseller_id == reseller_id.to_i)
  end

  def reset_prices_on_tickets
    transaction do
      tickets.each {|ticket| ticket.reset_price! }
    end
  end

  #
  # for_reseller is deprecated and will be removed when Widget v1 support is removed. Please use find_or_create.
  #
  def self.for_reseller(reseller_id = nil, params = {})
    ActiveSupport::Deprecation.warn("for_reseller is deprecated and will be removed when Widget v1 support is removed. Please use find_or_create.")
    reseller_id.blank? ? Cart.create(params) : Reseller::Cart.create( params.merge({:reseller => Organization.find(reseller_id)}) )
  end

  #
  # find_cart is deprecated and will be removed when Widget v1 support is removed. Please use find_or_create.  
  #
  def self.find_cart(cart_id, reseller_id)
    ActiveSupport::Deprecation.warn("find_cart is deprecated and will be removed when Widget v1 support is removed. Please use find_or_create.")
    Rails.logger.debug("Searching for cart [#{cart_id}] for reseller [#{reseller_id}]")
    rel = where(:id => cart_id)
    rel.where(:reseller_id => reseller_id) unless reseller_id.blank?
    rel.first
  end

  private

    def record_sold_price
      self.tickets.each do |ticket|
        ticket.sold_price = ticket.cart_price || ticket.price
        ticket.save
      end
    end

    def pay_with_authorization(payment, options)
      payment.purchase(options) ? approve! : reject!
    end

    def set_token
      self.token ||= SecureRandom.hex(32)
    end
end
