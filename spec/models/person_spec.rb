require 'spec_helper'

describe Person do
  disconnect_sunspot
  subject { FactoryGirl.create(:person) }

  it "should accept a note" do
    subject.notes.length.should eq 0
    subject.notes.build(:text => "This is my first note.")
    subject.save
    subject.notes.length.should eq 1
  end
  
  describe "adding phone number" do
    before(:each) do
      subject.phones.create(:number => "333-333-3333")
      subject.phones.create(:number => "444-444-4444")
    end
    
    it "should add the number" do
      subject.add_phone_if_missing("555-555-5555")
      subject.phones.length.should eq 3
      subject.phones.last.number.should eq "555-555-5555"
      subject.phones.last.kind.should eq "Other"
    end
    
    it "shouldn't add a number if it already exists" do
      subject.add_phone_if_missing("444-444-4444")
      subject.phones.length.should eq 2
      subject.phones.first.number.should eq "333-333-3333"
      subject.phones.last.number.should eq "444-444-4444"
    end
    
    it "shouldn't bother if the number is blnk or nil" do
      subject.add_phone_if_missing("")
      subject.phones.length.should eq 2
    end
  end
  
  describe "mergables" do
    
    let(:exceptions) { [:taggings, :base_tags, :tag_taggings, :tags, :tickets] }
    
    #This test is more of a reminder that when person gets a new has_many, it should
    #either be excluded explicitly here, or added to mergables
    it "should include all has_many associations excluding exceptions" do
      @has_manys= Person.reflect_on_all_associations.select{|d| d.macro == :has_many}
      @has_manys.reject! {|m| exceptions.include? m.name}
      @has_many_names = []
      @has_manys.collect {|m| @has_many_names << m.name}
      Person.mergables.should eq @has_many_names
    end
  end
  
  describe "calculating lifetime value" do
    it "should report a lifetime value of zero for a new record" do
      FactoryGirl.build(:person).lifetime_value.should eq 0
    end
    
    it "should calculate the lifetime value" do
      person = FactoryGirl.create(:person)
      order = FactoryGirl.create(:order, :person => person)
      items = 3.times.collect { FactoryGirl.create(:item, :order => order) }
      
      person.lifetime_value.should eq 0
      person.calculate_lifetime_value.should eq 15000
      person.lifetime_value.should eq 15000
    end
  end
  
  describe "merging" do
    describe "different orgs" do   
      before(:each) do
        @winner = FactoryGirl.create(:person, :organization => FactoryGirl.create(:organization))
        @loser = FactoryGirl.create(:person, :organization => FactoryGirl.create(:organization))
      end
       
      it "should throw an exception if the two person records are in different orgs" do
        lambda { Person.merge(@winner, @loser) }.should raise_error
      end
    end
    
    describe "a happier path" do
      before(:each) do
        @organization = FactoryGirl.create(:organization)
        @winner = FactoryGirl.create(:person, :organization => @organization)
        @winner.actions << FactoryGirl.create(:get_action, :person => @winner)
        @winner.orders  << FactoryGirl.create(:order, :person => @winner)
        @winner.tickets << FactoryGirl.create(:ticket, :buyer => @winner)
        @winner.notes.create(:text => 'winner')
        @winner.phones.create({:kind => 'Work', :number=>'1234567890'})
        @winning_address = FactoryGirl.create(:address, :person => @winner)
        @winner.address = @winning_address
        @winner.tag_list = 'east, west'
        @winner.lifetime_value = 2000
        @winner.save
        
        @loser = FactoryGirl.create(:person, :organization => @organization)
        @loser.actions << FactoryGirl.create(:get_action, :person => @loser)
        @loser.orders  << FactoryGirl.create(:order, :person => @loser)
        @loser.tickets << FactoryGirl.create(:ticket, :buyer => @loser)
        @loser.notes.create(:text => 'loser')
        @loser.phones.create({:kind => 'Cell', :number=>'3333333333'})
        @losing_address = FactoryGirl.create(:address, :person => @loser)
        @loser.address = @losing_address
        @loser.tag_list = 'west, north, south'
        @loser.lifetime_value = 1000
        @loser.do_not_email = true
        @loser.save
        
        @merge_result = Person.merge(@winner, @loser)
      end
    
      it "should return the winner" do
        @merge_result.id.should eq @winner.id
      end
    
      it "should merge the losers's actions into the winner's" do    
        @merge_result.actions.length.should eq 2
        @merge_result.actions.each do |action|
          action.person.should eq @merge_result
        end
      end
    
      it "should merge the loser's notes into the winner's" do  
        @merge_result.notes.length.should eq 2
        @merge_result.notes.each do |note|
          note.person.should eq @merge_result
        end
      end
      
           
      it "should change the loser's orders into the winner's" do
        @merge_result.orders.length.should eq 2
        @merge_result.orders.each do |order|
          order.person.should eq @merge_result
        end
      end
           
      it "should change the loser's tickets into the winner's" do
        @merge_result.tickets.length.should eq 2
        @merge_result.tickets.each do |ticket|
          ticket.buyer.should eq @merge_result
        end
      end
           
      it "should merge the phones" do
        @winner.phones.length.should eq 2
        @winner.phones[0].kind.should eq 'Work'
        @winner.phones[0].number.should eq '1234567890'
        @winner.phones[1].kind.should eq 'Cell'
        @winner.phones[1].number.should eq '3333333333'
      end
           
      it "should paranoid delete the loser" do
        ::Person.unscoped.find(@loser.id).deleted_at.should_not be_nil
      end
           
      it "should not change the winner's address" do
        @winner.address.should eq @winning_address
      end
      
      it "should merge the tags" do
        @winner.tag_list.should include('east')
        @winner.tag_list.should include('west')
        @winner.tag_list.should include('north')
        @winner.tag_list.should include('south')
        @winner.tag_list.length.should eq 4
      end

      it "should add the winner's and loser's lifetime values" do
        @merge_result.lifetime_value.should eq 3000
      end

      it "should copy do not email over if it was true" do
        @winner.should be_do_not_email
      end
    end
  end
  
  context "updating address" do
    let(:addr1)     { Address.new(:address1 => '123 A St.') }
    let(:addr2)     { Address.new(:address1 => '234 B Ln.') }
    let(:user)      { User.create() }
    let(:time_zone) { ActiveSupport::TimeZone["UTC"] }
  
    it "should create address when none exists, and add note" do
      num_notes = subject.notes.length
      subject.address.should be_nil
      subject.update_address(addr1, time_zone, user).should eq true
      subject.address.should_not be_nil
      subject.address.to_s.should eq addr1.to_s
      subject.notes.length.should eq num_notes + 1
    end
  
    it "should not update when nil address supplied" do
      num_notes = subject.notes.length
      old_addr = subject.address.to_s
      subject.update_address(nil, time_zone, user).should eq true
      subject.address.to_s.should eq old_addr
      subject.notes.length.should eq num_notes
    end
  
    it "should not update when address is unchanged" do
      subject.update_address(addr1, time_zone, user).should eq true
      num_notes = subject.notes.length
      old_addr = subject.address.to_s
      subject.update_address(addr1, time_zone, user).should eq true
      subject.address.to_s.should eq old_addr
      subject.notes.length.should eq num_notes
    end
  
    it "should update address when address is changed, and add note" do
      subject.update_address(addr1, time_zone, user).should eq true
      num_notes = subject.notes.length
      subject.update_address(addr2, time_zone, user).should eq true
      subject.address.to_s.should eq addr2.to_s
      subject.notes.length.should eq num_notes + 1
    end
  
    it "should allow a note with nil user" do
      num_notes = subject.notes.length
      subject.update_address(addr1, time_zone).should eq true
      subject.address.to_s.should eq addr1.to_s
      subject.notes.length.should eq num_notes + 1
    end
  end

  describe "#destroy" do
    it "should set :deleted_at to a time" do
      subject.deleted_at.should == nil
      subject.destroy.should == true
      subject.deleted_at.should_not == nil
    end
    context "when the person has actions" do
      before do
        subject.stub(:actions) {[1]}
      end
      it "should return false" do
        subject.destroy.should == false
      end
      it "should not be deleted" do
        expect{subject.destroy}.to_not change{subject.deleted_at}
      end
      context "BUT :with_prejudice is set to true" do
        it "should return true" do
          subject.destroy(with_prejudice: true).should == true
        end
        it "should be deleted" do
          expect{subject.destroy(with_prejudice: true)}.to change{subject.deleted_at}
        end
      end
    end
    context "when the person has orders" do
      before do
        subject.stub(:orders) {[1]}
      end
      it "should return false" do
        subject.destroy.should == false
      end
      it "should not be deleted" do
        expect{subject.destroy}.to_not change{subject.deleted_at}
      end
    end
    context "when the person has tickets" do
      before do
        subject.stub(:tickets) {[1]}
      end
      it "should return false" do
        subject.destroy.should == false
      end
      it "should not be deleted" do
        expect{subject.destroy}.to_not change{subject.deleted_at}
      end
    end
  end
  
  describe "#valid?" do
    it { should be_valid }
    it { should respond_to :email }
  
    it "should be valid with one of the following: first name, last name, email" do
      subject.email = 'something@somewhere.com'
      subject.first_name = nil
      subject.last_name = nil
      subject.should be_valid
  
      subject.email = nil
      subject.first_name = 'First!'
      subject.last_name = nil
      subject.should be_valid
  
      subject.email = nil
      subject.first_name = nil
      subject.last_name = 'Band'
      subject.should be_valid
  
      subject.email = nil
      subject.first_name = ''
      subject.last_name = 'Band'
      subject.should be_valid
    end
  
    it "should not be valid without a first name, last name or email address" do
      subject.first_name = nil
      subject.last_name = nil
      subject.email = nil
      subject.should_not be_valid
    end
  end
  
  describe "#find_or_create" do
    before(:each) do
      @organization = FactoryGirl.create(:organization)
    end
    
    it "should find the person specified by customer.person_id" do      
      @person = FactoryGirl.create(:person, :organization => @organization)
      customer = OpenStruct.new
      customer.person_id = @person.id
      person = Person.find_or_create(customer, @organization)
      person.should eq @person
    end
    
    it "should find the person if a person is passed in with an id" do
      @person = FactoryGirl.create(:person, :organization => @organization)
      checkout_person = Person.new
      checkout_person.id = @person.id
      person = Person.find_or_create(checkout_person, @organization)
      person.should eq @person
    end
    
    #This happens in reseller
    it "should not find the person if an id is passed but with the wrong org" do
      @person = FactoryGirl.create(:person, :organization => @organization)
      checkout_person = Person.new
      checkout_person.id = @person.id
      checkout_person.email = @person.email
      person = Person.find_or_create(checkout_person, FactoryGirl.create(:organization))
      person.email.should eq checkout_person.email
      person.should_not eq @person      
    end
    
    it "should create a new person if no id is passed" do
      @person = FactoryGirl.build(:person, :organization => @organization)
      person = Person.find_or_create(@person, @organization)
      person.id.should_not be_blank
      person.email.should         eq @person.email
      person.first_name.should    eq @person.first_name
      person.last_name.should     eq @person.last_name
      person.organization.should  eq @person.organization
    end
  end
  
  describe "#find_by_email_and_organization" do
    let(:organization) { FactoryGirl.build(:organization) }
  
    before(:each) do
      Person.stub(:find).and_return
    end
  
    it "should search for the Person by email address and organization" do
      params = {
        :email => "person@example.com",
        :organization_id => organization.id
      }
      Person.should_receive(:find).with(:first, :conditions => params)
      Person.find_by_email_and_organization("person@example.com", organization)
    end

    it "should return an empty array if it doesn't find anyone" do
      email = "person@example.com"
      p = Person.find_by_email_and_organization(email, organization)
      p.should eq []
    end
    
    it "should return nil if the email address is nil" do
      p = FactoryGirl.build(:person_without_email, :organization => organization)
      Person.find_by_email_and_organization(nil, organization).should be_nil
    end
  end
  
  describe "organization" do
    it { should respond_to :organization }
    it { should respond_to :organization_id }
  end
  
  describe "uniqueness" do
    subject { FactoryGirl.build(:person) }
    it "should not be valid if another person record exists with that email for the organization" do
      FactoryGirl.create(:person, :email => subject.email, :organization => subject.organization)
      subject.should_not be_valid
    end
  end
  
  describe "#dummy_for" do
    let(:organization) { FactoryGirl.build(:organization) }
  
    it "creates the dummy record if one does not yet exist" do
      person = Person.dummy_for(organization)
      person.dummy.should be_true
    end
  end

  describe "#create_subscribed_lists_notes!" do
    let(:user) { FactoryGirl.create(:user) }

    subject { FactoryGirl.build(:person) }

    context "mailchimp kit is setup" do
      include_context :mailchimp

      let!(:mailchimp_kit) { FactoryGirl.create(:mailchimp_kit, :organization => subject.organization) }
      let(:list_id) { mailchimp_kit.attached_lists.first[:list_id] }

      before do
        subject.save
      end

      it "should create a note for changing do not email to true" do
        subject.update_attributes(:do_not_email => true)
        subject.create_subscribed_lists_notes!(user)

        subject.should have(1).notes
        note = subject.notes.first
        note.text.should == "#{user.email} changed do not email to true"
      end

      it "should create a note for changing do not email to false" do
        subject.update_attributes(:do_not_email => true)
        subject.update_attributes(:do_not_email => false)
        subject.create_subscribed_lists_notes!(user)

        subject.should have(1).notes
        note = subject.notes.first
        note.text.should == "#{user.email} changed do not email to false"
      end

      it "should not create a note if do not email did not change" do
        subject.create_subscribed_lists_notes!(user)

        subject.should have(0).notes
      end

      it "should create a note when someone subscribes to a list" do
        subject.update_attributes(:subscribed_lists => ["list_id"])
        subject.update_attributes(:subscribed_lists => ["list_id", list_id])
        subject.create_subscribed_lists_notes!(user)

        subject.should have(1).notes
        note = subject.notes.first
        note.text.should == "#{user.email} changed subscription status of the MailChimp list First List to subscribed"
      end

      it "should create a note when someone unsubscribes to a list" do
        subject.update_attributes(:subscribed_lists => ["list_id", list_id])
        subject.update_attributes(:subscribed_lists => ["list_id"])
        subject.create_subscribed_lists_notes!(user)

        subject.should have(1).notes
        note = subject.notes.first
        note.text.should == "#{user.email} changed subscription status of the MailChimp list First List to unsubscribed"
      end

      it "should create a note when someone changes do not email and unsubscribes from a list" do
        subject.update_attributes(:subscribed_lists => [list_id])
        subject.update_attributes(:do_not_email => true)
        subject.create_subscribed_lists_notes!(user)

        subject.should have(2).notes
        note = subject.notes.first
        note.text.should == "#{user.email} changed do not email to true"
        note = subject.notes.last
        note.text.should == "#{user.email} changed subscription status of the MailChimp list First List to unsubscribed"
      end
    end

    context "no mailchimp kit" do
      it "should create a note for changing do not email to true" do
        subject.update_attributes(:do_not_email => true)
        subject.create_subscribed_lists_notes!(user)

        subject.should have(1).notes
        note = subject.notes.first
        note.text.should == "#{user.email} changed do not email to true"
      end

      it "should create a note for changing do not email to false" do
        subject.update_attributes(:do_not_email => true)
        subject.update_attributes(:do_not_email => false)
        subject.create_subscribed_lists_notes!(user)

        subject.should have(1).notes
        note = subject.notes.first
        note.text.should == "#{user.email} changed do not email to false"
      end

      it "should not create a note if do not email did not change" do
        subject.create_subscribed_lists_notes!(user)

        subject.should have(0).notes
      end
    end
  end
end
