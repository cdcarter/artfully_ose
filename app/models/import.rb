class Import < ActiveRecord::Base
  
  include Imports::Status
  include Imports::Processing

  has_many :import_errors, :dependent => :delete_all
  has_many :import_messages, :dependent => :delete_all
  has_many :import_rows, :dependent => :delete_all
  has_many :people, :dependent => :destroy
  has_many :actions, :dependent => :destroy
  has_many :events, :dependent => :destroy
  has_many :orders, :dependent => :destroy

  serialize :import_headers
  
  set_watch_for :created_at, :local_to => :organization

  DATE_INPUT_FORMAT = "%m/%d/%Y"
  DATE_INPUT_FORMAT_WITH_TIME = "%m/%d/%Y %l:%M%P"
  
  def message(row_number=nil, parsed_row=nil, person, message_text)
    self.import_messages.create({:row_number => row_number, :row_data => parsed_row.try(:row), :person => person, :message => message_text})
  end

  def self.build(type)
    case type
    when "events"
      EventsImport.new
    when "people"
      PeopleImport.new
    when "donations"
      DonationsImport.new
    else
      nil
    end
  end

  def headers
    self.import_headers
  end

  def rows
    self.import_rows.map(&:content)
  end

  def perform
    if status == "caching"
      self.cache_data
    elsif status == "approved"
      self.import
      Sunspot.delay.commit
    end
  end

  def import
    self.importing!

    self.people.destroy_all
    self.import_errors.delete_all

    rows.each_with_index do |row, index|
      begin
        Rails.logger.info("----- Import #{id} Processing row #{index} ------")
        process(ParsedRow.parse(headers, row))
      rescue => error
        fail!(error, row, index)
        return
      end
    end
    self.imported!
  end
  
  #
  # This composes errors thrown *during* the import.  For validation errors, see invalidate!
  #
  def fail!(error = nil, row = nil, row_num = 0)
    Rails.logger.error "IMPORT ERROR [#{self.id}]: #{error.message}"
    error.backtrace.each { |line| Rails.logger.error "     #{line}" }
    self.import_errors.create! :row_data => row, :error_message => "Row #{row_num}: #{error.message}"
    failed!
    rollback
  end
  
  #Subclasses must implement process and rollback
  def process(parsed_row)
  end
  
  def rollback
  end

  def recallable?
    false
  end

  def parsed_rows
    return @parsed_rows if @parsed_rows
    @parsed_rows = []
    
    rows.each do |row|
      @parsed_rows << ParsedRow.parse(headers, row)
    end
    @parsed_rows
  end

  def cache_data
    raise "Cannot load CSV data" unless csv_data.present?

    self.import_headers = nil
    self.import_rows.delete_all
    self.import_errors.delete_all

    csv_data.gsub!(/\\"(?!,)/, '""') # Fix improperly escaped quotes.

    CSV.parse(csv_data, :headers => false) do |row|
      if self.import_headers.nil?
        self.import_headers = row.to_a
        #TODO: Validate headers right here
        self.save!
      else
        self.import_rows.create!(:content => row.to_a)
        parsed_row = ParsedRow.parse(self.import_headers, row.to_a)
        
        unless row_valid?(parsed_row)
          self.invalidate! 
          return
        end
      end
    end

    self.pending!
    
  #TODO: Needs to be re-worked to include the row number in the error
  rescue CSV::MalformedCSVError => e
    error_message = "There was an error while parsing the CSV document: #{e.message}"
    self.import_errors.create!(:error_message => error_message)
    self.invalidate!
  rescue Exception => e
    self.import_errors.create!(:error_message => e.message)
    self.invalidate!
  rescue Import::RowError => e
    self.import_errors.create!(:error_message => e.message)
    self.invalidate!
  end

  def hash_address(parsed_row)
    parsed_row.address_attributes
  end

  def attach_person(parsed_row)
    person = self.people.build(parsed_row.person_attributes)
    person.organization = self.organization

    person.build_address(hash_address(parsed_row))
    person.tag_list = parsed_row.tags_list.join(", ")

    1.upto(3) do |n|
      kind = parsed_row.send("phone#{n}_type")
      number = parsed_row.send("phone#{n}_number")
      if kind.present? && number.present?
        person.phones << Phone.new(kind: kind, number: number)
      end
    end
    person.skip_commit = true
    person
  end

  class RowError < ArgumentError
  end
  
  class RuntimeError < ArgumentError
  end

end
