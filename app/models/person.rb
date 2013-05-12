class Person < ActiveRecord::Base
  include Valuation::LifetimeValue
  include Valuation::LifetimeDonations
  include OhNoes::Destroy

  attr_accessor :skip_sync_to_mailchimp, :skip_commit
  attr_accessible :type, :email, :salutation, :dummy, :title, :first_name, :last_name, :company_name, :website, :twitter_handle, :linked_in_url, :facebook_url, :person_type, :address_attributes, :phones_attributes

  attr_accessible :subscribed_lists, :do_not_email, :skip_sync_to_mailchimp
  attr_accessible :organization_id
  
  acts_as_taggable

  belongs_to  :organization
  belongs_to  :import
  has_many    :actions
  has_many    :phones
  has_many    :notes
  has_many    :orders
  has_many    :tickets, :foreign_key => 'buyer_id'
  has_one     :address, :validate => false

  accepts_nested_attributes_for :address, :allow_destroy => false
  accepts_nested_attributes_for :phones, :reject_if => lambda { |p| p[:number].blank? }, :allow_destroy => true
  
  default_scope where(:deleted_at => nil)
  before_save :check_do_not_email
  after_update :sync_update_to_mailchimp, :except => :create
  serialize :subscribed_lists, Array
  validates_presence_of :organization_id
  validates_presence_of :person_info

  validates :email, :uniqueness => { :scope => [:organization_id, :deleted_at], :message => " %{value} has already been taken." }, :allow_blank => true
  
  def dupe_code
    "#{first_name} | #{last_name} | #{email}"
  end
  
  def self.find_dupes_in(organization)
    hash = {}
    Person.where(:organization_id => organization.id)
          .where(:import_id => nil)
          .includes([:tickets, :actions, :notes, :orders]).each do |p|
      if hash[p.dupe_code].nil?
        hash[p.dupe_code] = Array.wrap(p)
      else
        hash[p.dupe_code] << p
      end
    end
    hash
  end

  def posessive
    self.first_name.blank? ? "" : "#{self.first_name}'s"
  end
  
  #
  # An array of has_many associations that should be merged when a person record is merged with another
  # When an has_many association is added, it must be added here if the association is to be merged
  #
  # Tickets are a special case
  #
  def self.mergables
    [:actions, :phones, :notes, :orders]
  end
  
  def has_something?
    !has_nothing?
  end
  
  def has_nothing?
    actions.empty? && phones.empty? && notes.empty? && orders.empty? && tickets.empty? && address.nil? && import_id.nil?
  end

  def destroyable?
    actions.empty? && orders.empty? && tickets.empty?
  end

  searchable do
    text :first_name, :last_name, :email
    text :address do
      address.to_s unless address.nil?
    end
    
    text :tags do
      taggings.map{ |tagging| tagging.tag.name }
    end
    
    text :notes do
      notes.map{ |note| note.text }.join(" ")
    end
    
    string :first_name, :last_name, :email
    string :organization_id do
      organization.id
    end
  end
  include Ext::DelayedIndexing

  comma do
    email
    salutation
    first_name
    last_name
    title
    company_name
    address("Address 1") { |address| address && address.address1 }
    address("Address 2") { |address| address && address.address2 }
    address("City") { |address| address && address.city }
    address("State") { |address| address && address.state }
    address("Zip") { |address| address && address.zip }
    address("Country") { |address| address && address.country }
    phones("Phone1 type") { |phones| phones[0] && phones[0].kind }
    phones("Phone1 number") { |phones| phones[0] && phones[0].number }
    phones("Phone2 type") { |phones| phones[1] && phones[1].kind }
    phones("Phone2 number") { |phones| phones[1] && phones[1].number }
    phones("Phone3 type") { |phones| phones[2] && phones[2].kind }
    phones("Phone3 number") { |phones| phones[2] && phones[2].number }
    website
    twitter_handle
    facebook_url
    linked_in_url
    tags { |tags| tags.join("|") }
    person_type
    do_not_email
  end

  def self.find_by_import(import)
    where('import_id = ?', import.id)
  end

  def self.recent(organization, limit = 10)
    Person.where(:organization_id => organization).order('updated_at DESC').limit(limit)
  end
  
  def self.merge(winner, loser)
    unless winner.organization == loser.organization
      raise "Trying to merge two people [#{winner.id}] [#{loser.id}] from different organizations [#{winner.organization.id}] [#{winner.organization.id}]"
    end
    
    mergables.each do |mergable|
      loser.send(mergable).each do |m|
        m.person = winner
        m.save!
      end
    end
    
    loser.tickets.each do |ticket|
      ticket.update_column(:buyer_id, winner.id)
    end
    
    loser.tags.each do |t|
      winner.tag_list << t.name unless winner.tag_list.include? t.name
    end

    winner.lifetime_value += loser.lifetime_value
    winner.lifetime_donations += loser.lifetime_donations

    winner.do_not_email = true if loser.do_not_email?
    new_lists = loser.subscribed_lists - winner.subscribed_lists
    winner.subscribed_lists = winner.subscribed_lists.concat(loser.subscribed_lists).uniq
    winner.save!
    loser.destroy(with_prejudice: true)

    mailchimp_kit = winner.organization.kits.mailchimp
    MailchimpSyncJob.merged_person(mailchimp_kit, loser.email, winner.id, new_lists) if mailchimp_kit

    return winner
  end

  def lifetime_ticket_value
    self.lifetime_value - self.lifetime_donations
  end
  
  def self.find_by_email_and_organization(email, organization)
    return nil if email.blank? 
    find(:first, :conditions => { :email => email, :organization_id => organization.id })
  end

  def self.find_by_organization(organization)
    find_by_organization_id(organization.id)
  end

  def self.dummy_for(organization)
    dummy = find(:first, :conditions => { :organization_id => organization.id, :dummy => true })
    if dummy.nil?
      create_dummy_for(organization)
    else
      dummy
    end
  end

  def self.create_dummy_for(organization)
    create({
      :first_name      => "Anonymous",
      :email           => "anonymous@artfullyhq.com",
      :dummy           => true,
      :organization_id => organization.id
    })
  end

  def starred_actions
    Action.where({ :person_id => id, :starred => true }).order(:occurred_at)
  end

  def unstarred_actions
    Action.where({ :person_id => id }).order('occurred_at desc').select{|a| a.unstarred?}
  end
  
  def self.first_or_create(attributes=nil, options ={}, &block)
    attributes[:organization_id] ||= attributes[:organization].try(:id)
    raise(ArgumentError, "You must include an organization when searching for people") if attributes[:organization_id].blank?
    return Person.create(attributes, options, &block)                                  if attributes[:email].blank?
    
    attributes.delete(:organization)
    
    Person.where(:email => attributes[:email]).where(:organization_id => attributes[:organization_id]).first || Person.create(attributes, options, &block) 
  end

  #
  # You can pass any object as first param as long as it responds to
  # .first_name, .last_name, and .email
  #
  def self.find_or_create(customer, organization)
    warn "[DEPRECATION] find_or_create will be removed in a future release. Please use first_or_create"
    
    #TODO: Yuk
    if (customer.respond_to? :person_id) && (!customer.person_id.nil?)
      return Person.find(customer.person_id)
    elsif (customer.is_a? Person) && (!customer.id.nil?)
      person = Person.where(:id => customer.id).where(:organization_id => organization.id).first
      return person if person
    end
    
    person = Person.find_by_email_and_organization(customer.email, organization)
      
    if person.nil?
      params = {
        :first_name      => customer.first_name,
        :last_name       => customer.last_name,
        :email           => customer.email,
        :organization_id => organization.id
      }
      person = Person.create(params)
    end
    person
  end

  # Needs a serious refactor
  def update_address(new_address, time_zone, user = nil, updated_by = nil)
    unless new_address.nil?
      new_address = Address.unhash(new_address) 
      new_address.person = self
      @address = Address.find_or_create(id)
      if !@address.update_with_note(self, user, new_address, time_zone, updated_by)
        ::Rails.logger.error "Could not update address from payment"
        return false
      end
      self.address = @address
      save
    end
    true
  end

  #
  # Will add a phone number ot this record if the number doesn't already exist
  #
  def add_phone_if_missing(new_phone)
    if (!new_phone.blank? and phones.where("number = ?", new_phone).empty?)
      phones.create(:number => new_phone, :kind => "Other")
    end
  end
  
  def new_note(text, occurred_at, user, organization_id)
    note = notes.create({
      :text => text,
      :occurred_at => Time.now
    })    
    note.user_id = user.id
    note.organization_id = organization_id
    note.save
    note
  end

  def create_subscribed_lists_notes!(user)
    if previous_changes["do_not_email"]
      new_note("#{user.email} changed do not email to #{do_not_email}",Time.now,user,organization.id)
    end

    if previous_changes["subscribed_lists"]
      mailchimp_kit.attached_lists.each do |list|
        old_lists = previous_changes["subscribed_lists"][0]
        if !old_lists.include?(list[:list_id]) && subscribed_lists.include?(list[:list_id])
          new_note("#{user.email} changed subscription status of the MailChimp list #{list[:list_name]} to subscribed",Time.now,user,organization.id)
        elsif old_lists.include?(list[:list_id]) && !subscribed_lists.include?(list[:list_id])
          new_note("#{user.email} changed subscription status of the MailChimp list #{list[:list_name]} to unsubscribed",Time.now,user,organization.id)
        end
      end
    end
  end

  def to_s
    if first_name.present? && last_name.present?
      "#{first_name} #{last_name}"
    elsif first_name.present?
      first_name.to_s
    elsif last_name.present?
      last_name.to_s
    elsif email.present?
      email.to_s
    elsif id.present?
      "No Name ##{id}"
    else
      "No Name"
    end
  end

  #Bad name.  This will respond with true if there is something in first_name, last_name, or email.  False otherwise.
  def person_info
    !(first_name.blank? and last_name.blank? and email.blank?)
  end

  private
    def sync_update_to_mailchimp
      return if skip_sync_to_mailchimp
      return unless mailchimp_changes? && mailchimp_kit
      job = MailchimpSyncJob.new(mailchimp_kit, :type => :person_update_to_mailchimp, :person_id => id, :person_changes => changes)
      Delayed::Job.enqueue(job, :queue => "mailchimp") if !mailchimp_kit.cancelled?
    end

    def mailchimp_kit
      @mailchimp_kit ||= organization.kits.detect { |kit| kit.is_a?(MailchimpKit) }
    end

    def mailchimp_changes?
      ["first_name", "last_name", "email", "do_not_email", "subscribed_lists"].any? { |attr| changes.keys.include?(attr) }
    end

    def check_do_not_email
      self.subscribed_lists = [] if do_not_email
    end
end
