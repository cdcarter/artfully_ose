class Exchange
  include Adjustments
  include ActiveModel::Validations

  attr_accessor :order, :items, :tickets, :service_fee
  attr_reader :exchange_order

  validates_presence_of :order
  validates_length_of :items,   :minimum => 1
  validates_length_of :tickets, :minimum => 1
  validate :items_are_exchangeable
  validate :tickets_match_items
  validate :tickets_are_available
  validate :tickets_belong_to_organization

  #The original order
  #The items to exchange
  #The tickets that they are being exchanged for
  def initialize(order, items, tickets = [])
    self.order        = order
    self.items        = items
    self.tickets      = tickets
    self.service_fee  = number_of_non_free_items(items) * service_fee_per_item(order.items)
  end

  def items_are_exchangeable
    errors.add(:items, "are not available to exchange") unless items.all?(&:exchangeable?)
  end

  def tickets_match_items
    errors.add(:tickets, "must match the items to exchange") unless tickets.length == items.length
  end

  def tickets_are_available
    errors.add(:tickets, "are not available to exchange") if tickets.any?(&:committed?)
  end

  def tickets_belong_to_organization
    errors.add(:tickets, "do not belong to this organization") unless tickets.all? { |ticket| order.organization.can? :manage, ticket }
  end

  def submit
    ActiveRecord::Base.transaction do
      sell_new_items
      return_old_items
      adjust_original_order
    end
  end

  def return_old_items
    items.map(&:exchange!)
  end

  def adjust_original_order
    order.service_fee = order.service_fee - service_fee
    order.save
  end

  def sell_new_items
    exchange_order_timestamp = Time.now
    tickets.each { |ticket| ticket.exchange_to(order.person, exchange_order_timestamp) }
    create_order(exchange_order_timestamp)
  end

  def create_order(time=Time.now)
    exchange_order = ExchangeOrder.new.tap do |exchange_order|
      exchange_order.person = order.person
      exchange_order.parent = order
      exchange_order.payment_method = order.payment_method
      exchange_order.created_at = time
      exchange_order.service_fee = service_fee
      exchange_order.for_organization order.organization
      exchange_order.details = "Order is the result of an exchange on #{I18n.l time, :format => :slashed_date}"
      exchange_order << tickets
    end
    exchange_order.record_exchange! items
    exchange_order.save!
    @exchange_order = exchange_order
  end
end
