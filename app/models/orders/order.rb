#Subclasses (and their type) should speak to the *location* or *nature* of the order, not the contents of the items
# WebOrder, BoxOfficeOrder for example.  NOT DonationOrder, since orders may contain multiple different item types
class Order < ActiveRecord::Base
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper
  include Ext::Integrations::Order
  include OhNoes::Destroy
  include ArtfullyOseHelper
  
  #This is a lambda used to by the items to calculate their net
  attr_accessor :per_item_processing_charge

  attr_accessible :person_id, :organization_id, :person, :organization, :details

  belongs_to :person
  belongs_to :organization
  belongs_to :import
  belongs_to :parent, :class_name => "Order", :foreign_key => "parent_id"
  belongs_to :gateway_transaction, :primary_key => :transaction_id, :foreign_key => :transaction_id
  has_many :children, :class_name => "Order", :foreign_key => "parent_id"
  has_many :items, :dependent => :destroy
  has_many :actions, :foreign_key => "subject_id", :dependent => :destroy

  attr_accessor :skip_actions

  set_watch_for :created_at, :local_to => :organization  
  set_watch_for :created_at, :local_to => :self, :as => :admins

  validates_presence_of :person_id
  validates_presence_of :organization_id

  # The three of these are handle_asynchronously
  after_create :create_purchase_action, :unless => :skip_actions
  after_create :create_donation_actions, :unless => :skip_actions
  after_save :calculate_lifetime_value

  after_create :sell_tickets

  default_scope :order => 'orders.created_at DESC'
  scope :before, lambda { |time| where("orders.created_at < ?", time) }
  scope :after,  lambda { |time| where("orders.created_at > ?", time) }
  scope :imported, where("fa_id IS NOT NULL")
  scope :not_imported, where("fa_id IS NULL")
  scope :csv_imported, where("import_id IS NOT NULL")
  scope :csv_not_imported, where("import_id IS NULL")
  scope :artfully, where("transaction_id IS NOT NULL")

  searchable do
    text :details, :id, :type, :location, :transaction_id, :payment_method, :special_instructions

    [:first_name, :last_name, :email].each do |person_field|
      text person_field do
        person.send(person_field) unless person.nil?
      end
    end

    text :organization_id do
      organization.id
    end

    text :organization_name do
      organization.name
    end

    text :event_name do
      items.map{ |item| item.show.event.name unless item.show.nil? }
    end

    string :details, :id, :type, :location, :transaction_id, :payment_method, :special_instructions
    string :organization_id do
      organization.id
    end

    string :organization_name do
      organization.name
    end

    string :event_name, :multiple => true do
      items.map{ |item| item.show.event.name unless item.show.nil? }
    end
  end
  include Ext::DelayedIndexing

  def self.in_range(start, stop, organization_id = nil)
    query = after(start).before(stop).includes(:items, :person, :organization).order("created_at DESC")
    if organization_id.present?
      query.where('organization_id = ?', organization_id)
    else
      query
    end
  end
  
  def artfully?
    !transaction_id.nil?
  end
  
  def location
    self.class.location
  end
  
  def self.location
    ""
  end

  def total
    all_items.inject(0) {|sum, item| sum + item.total_price.to_i }
  end

  def nongift_amount
    all_items.inject(0) {|sum, item| sum + item.nongift_amount.to_i }
  end
  
  def destroyable?
    ( (type.eql? "ApplicationOrder") || (type.eql? "ImportedOrder") ) && !is_fafs? && !artfully? && has_single_donation?
  end
  
  def editable?
    ( (type.eql? "ApplicationOrder") || (type.eql? "ImportedOrder") ) && !is_fafs? && !artfully? && has_single_donation? 
  end

  def for_organization(org)
    self.organization = org
  end

  def <<(products)
    self.items << Array.wrap(products).collect { |product|  Item.for(product, @per_item_processing_charge) }
  end

  def payment
    CreditCardPayment.new(:transaction_id => transaction_id)
  end

  def record_exchange!(exchanged_items)
    items.each_with_index do |item, index|
      item.to_exchange! exchanged_items[index]
    end
  end

  def all_items
    merge_and_sort_items
  end

  def all_tickets
    all_items.select(&:ticket?)
  end

  #TODO: Undupe these methods
  def tickets
    items.select(&:ticket?)
  end

  def all_donations
    all_items.select(&:donation?)
  end

  def donations
    items.select(&:donation?)
  end
  #End dupes
  
  def has_single_donation?
    (donations.size == 1) && tickets.empty?
  end

  def settleable_donations
    all_donations.reject(&:modified?)
  end

  def refundable_items
    return [] unless Payment.create(payment_method).refundable?
    items.select(&:refundable?)
  end

  def exchangeable_items
    items.select(&:exchangeable?)
  end

  def returnable_items
    items.select { |i| i.returnable? and i.comped? and not i.refundable? }
  end

  def num_tickets
    all_tickets.size
  end

  def has_ticket?
    items.select(&:ticket?).present?
  end

  def has_donation?
    items.select(&:donation?).present?
  end

  def sum_donations
    all_donations.collect{|item| item.total_price.to_i}.sum
  end

  #
  # Will return an array of all discount codes on all items on this order
  #
  def discounts_used
    items.map{|i| i.discount.try(:code)}.reject(&:blank?).uniq
  end

  def ticket_details
    discount_string = ""
    unless discounts_used.empty?
      discount_string = ", used #{'discount'.pluralize(discounts_used.length)} " + discounts_used.join(",")
    end
    Ticket.to_sentence(self.tickets.map(&:product)) + discount_string
  end
  
  def to_comp!
    items.each do |item|
      item.to_comp!
    end
  end

  def is_fafs?
    !fa_id.nil?
  end

  def donation_details
    if is_fafs?
      "#{number_as_cents sum_donations} donation made through Fractured Atlas"
    else
      "#{number_as_cents sum_donations} donation"
    end
  end
  
  def ticket_summary
    summary = TicketSummary.new
    items.select(&:ticket?).each do |item|
      summary << item.product
    end
    summary
  end

  def credit?
    payment_method.eql? CreditCardPayment.payment_method
  end

  def cash?
    payment_method.eql? CashPayment.payment_method
  end

  def original_order
    if self.parent.nil?
      return self
    else
      return self.parent.original_order
    end
  end

  #
  # If this order has no transaction_id, run up the parent chain until we hit one
  # This is needed for exchanges that ultimately need to be refunded
  #
  def transaction_id
    read_attribute(:transaction_id) || self.parent.try(:transaction_id)
  end
  
  def sell_tickets
    all_tickets.each do |item|
      item.product.sell_to(self.person, self.created_at)
    end
  end
  
  def time_zone
    "Eastern Time (US & Canada)"
  end

  def contact_email
    items.try(:first).try(:show).try(:event).try(:contact_email)
  end

  def calculate_lifetime_value
    self.person.calculate_lifetime_value
    self.person.calculate_lifetime_donations
  end
  handle_asynchronously :calculate_lifetime_value

  def create_donation_actions
    items.select(&:donation?).collect do |item|
      action                    = GiveAction.new
      action.person             = person
      action.subject            = self
      action.organization_id    = organization.id
      action.details            = donation_details
      action.occurred_at        = created_at
      action.subtype            = "Monetary"
      action.save!
      action
    end
  end
  handle_asynchronously :create_donation_actions

  def create_purchase_action
    unless all_tickets.empty?
      action                  = purchase_action_class.new
      action.person           = person
      action.subject          = self
      action.organization     = organization
      action.details          = ticket_details
      action.occurred_at      = created_at

      #Weird, but Rails can't initialize these so the subtype is hardcoded in the model
      action.subtype          = action.subtype
      action.import           = self.import if self.import
      action.save!
      action
    end
  end
  handle_asynchronously :create_purchase_action

  def purchase_action_class
    GetAction
  end

  private

    #this used to do more.  Now it only does this
    def merge_and_sort_items
      items
    end
end
