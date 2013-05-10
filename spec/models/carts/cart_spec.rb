require 'spec_helper'
require 'support/active_merchant_test_helper'

describe Cart do
  disconnect_sunspot
  include ActiveMerchantTestHelper
  subject { FactoryGirl.build(:cart) }

  it "should be marked as unfinished in the started state" do
    subject.state = :started
    subject.should be_unfinished
  end

  it "should be marked as unfinished in the rejected state" do
    subject.state = 'rejected'
    subject.should be_unfinished
  end

  describe "validations" do
    let(:cart) { Cart.new }
    it "should make sure the token is exactly 64 characters" do
      cart.token = 'a' * 63
      cart.should_not be_valid
      cart.errors[:token].should include("is the wrong length (should be 64 characters)")
    end
    it "should make sure the token only consists of hex digits" do
      cart.token = 'g' * 64
      cart.should_not be_valid
      cart.errors[:token].should include("is invalid")
      cart.token = 'f' * 64
      cart.valid?
      cart.errors[:token].should be_empty
    end
  end

  describe "with items" do
    it { should respond_to :items }

    it "should be empty without any items" do
      subject.should be_empty
    end
  end

  describe "#subtotal" do
    let(:items) { 10.times.collect{ mock(:item, :price => 10, :cart_price => 20) }}
    it "should sum up the price of the tickets" do
      subject.stub(:items) { items }
      subject.subtotal.should eq 100
    end
  end

  describe "#total" do
    let(:items) { 10.times.collect{ mock(:item, :cart_price => 10, :price => 20) }}
    it "should sum up the price of the tickets" do
      subject.stub(:items) { items }
      subject.total.should eq 100
    end
  end

  describe "ticket fee" do
    let(:tickets) { 2.times.collect { FactoryGirl.build(:ticket) } }
    let(:free_tickets) { 2.times.collect { FactoryGirl.build(:free_ticket) } }

    it "should have a fee of 0 if there are no tickets" do
      subject.fee_in_cents.should eq 0
    end

    it "should have a fee of 0 if there are free tickets" do
      subject << free_tickets
      subject.fee_in_cents.should eq 0
      subject << tickets
      subject.fee_in_cents.should eq 400
    end

    it "should keep the fee updated while tickets are added" do
      subject << tickets
      subject.fee_in_cents.should eq 400
    end

    it "should have a 0 fee if there is a donation" do
      donation = FactoryGirl.build(:donation)
      subject.donations << donation
      subject.fee_in_cents.should eq 0
      subject << tickets
      subject.fee_in_cents.should eq 400
    end

    it "should not include the fee in the subtotal" do
      subject << tickets
      subject.fee_in_cents.should eq 400
      subject.subtotal.should eq 10000
    end

    it "should include the fee in the total" do
      subject << tickets
      subject.fee_in_cents.should eq 400
      subject.total.should eq 10400
    end
  end

  describe "#pay_with" do
    let(:payment) { mock(:payment, :amount => 100) }

    it "saves the cart after payment" do
      payment.stub(:requires_authorization?) { false }
      subject.should_receive(:save!)
      subject.pay_with(payment)
    end

    describe "authorization" do
      it "attempt to authorize the payment if required" do
        payment.stub(:requires_authorization?) { true }
        payment.should_receive(:purchase).and_return(successful_response)
        subject.pay_with(payment)
      end

      it "does not attempt to authorize the payment if it is not required" do
        payment.stub(:requires_authorization?).and_return(false)
        payment.should_not_receive(:purchase)
        subject.pay_with(payment)
      end
    end

    describe "state transitions" do
      it "should transition to approved when the payment is approved" do
        payment.stub(:requires_authorization?).and_return(true)
        payment.stub(:purchase).and_return(successful_response)
        subject.pay_with(payment)
        subject.should be_approved
      end

      it "should mark the tickets sold_price with the current cart_price when approved" do
        subject.tickets = 2.times.collect { FactoryGirl.build(:ticket, :cart_price => 400) }
        payment.stub(:requires_authorization?).and_return(true)
        payment.stub(:purchase).and_return(successful_response)
        subject.pay_with(payment)
        subject.should be_approved
        subject.tickets.each do |ticket|
          ticket.reload.sold_price.should eq 400
        end
      end

      it "should mark the tickets sold_price with the current cart_price when approved even if cart_price is 0" do
        subject.tickets = 2.times.collect { FactoryGirl.build(:ticket, :cart_price => 0) }
        payment.stub(:requires_authorization?).and_return(true)
        payment.stub(:purchase).and_return(successful_response)
        subject.pay_with(payment)
        subject.should be_approved
        subject.tickets.each do |ticket|
          ticket.sold_price.should eq 0
        end
      end

      it "should mark the tickets sold_price with the ticket.price is cart_price is nil when approved" do
        subject.tickets = 2.times.collect { FactoryGirl.build(:ticket, :price => 32, :cart_price => nil) }
        payment.stub(:requires_authorization?).and_return(true)
        payment.stub(:purchase).and_return(successful_response)
        subject.pay_with(payment)
        subject.should be_approved
        subject.tickets.each do |ticket|
          ticket.sold_price.should eq 32
        end
      end

      it "should tranisition to rejected when the Payment is rejected" do
        payment.stub(:requires_authorization?).and_return(true)
        payment.stub(:purchase).and_return(false)
        subject.pay_with(payment)
        subject.should be_rejected
      end

      it "should transition to approved if no authorization is required for the payment" do
        payment.stub(:requires_authorization?).and_return(false)
        subject.pay_with(payment)
        subject.should be_approved
      end
    end
  end

  describe "organizations" do
    it "includes the organizations for the included donations" do
      donation = FactoryGirl.build(:donation)
      subject.donations << donation
      subject.organizations.should include donation.organization
    end

    it "includes the organizations for the included tickets" do
      ticket = FactoryGirl.build(:ticket)

      subject.tickets << ticket
      subject.organizations.should include ticket.organization
    end
  end

  describe ".clear_donations" do
    it "should do nothing when there are no donations" do
      donations = subject.clear_donations
      subject.donations.size.should eq 0
      donations.size.should eq 0
    end

    it "should clear when there is one donation" do
      donation = FactoryGirl.build(:donation)
      subject.donations << donation
      donations = subject.clear_donations
      subject.donations.size.should eq 0
      donations.size.should eq 1
      donations.first.should eq donation
    end

    it "should clear when there are two donations" do
      donation = FactoryGirl.build(:donation)
      donation2 = FactoryGirl.build(:donation)
      subject.donations << donation
      subject.donations << donation2
      donations = subject.clear_donations
      subject.donations.size.should eq 0
      donations.size.should eq 2
      donations.first.should eq donation
      donations[1].should eq donation2
    end
  end

  describe ".find_or_create" do
    let!(:requested_token) { nil }
    let(:found_cart) { Cart.find_or_create(requested_token, nil) }
    context "when no cart token is supplied" do
      it "should raise a not found exception" do
        expect { found_cart }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
    context "when a non-existent, invalid cart token is supplied" do
      let!(:requested_token) { "no such token" }
      it "should raise an exception" do
        expect { found_cart }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
    context "when a non-existent, valid cart token is supplied" do
      let!(:requested_token) { 'f0eaa98acc5e600fb71dcf8affca2061f0eaa98acc5e600fb71dcf8affca2061' }
      it "should return a new cart" do
        found_cart.should be_a_kind_of(Cart)
      end
      it "should have the same token" do
        found_cart.token.should eql(requested_token)
      end
    end
    context "when the existing cart token is supplied" do
      let(:requested_token) { existing_cart.token }
      let!(:existing_cart) { FactoryGirl.create :cart_with_items }
      it "should return the cart that has that token" do
        found_cart.token.should eql(requested_token)
        found_cart.items.should_not be_empty
      end
      context "and when the original cart was completed" do
        before do
          existing_cart.approve!
        end
        it "should give us an empty cart" do
          found_cart.items.should be_empty
        end
        it "should give us a cart with the proper token" do
          found_cart.token.should eql(requested_token)
        end
        it "should have removed the token from the original cart object" do
          found_cart
          existing_cart.reload
          existing_cart.token.should_not eql(requested_token)
        end
        it "should leave the items in the original cart" do
          existing_cart.items.should_not be_empty
        end
      end
    end
  end

  describe "#reset_prices_on_tickets" do
    let(:discount_amount) { 10 }
    let(:price) { 20 }
    let(:ticket) { FactoryGirl.build(:ticket, :price => price, :cart_price => price - discount_amount) }
    before(:each) do
      subject.tickets << ticket
    end

    it "should set tickets back to their original prices" do
      expect {subject.reset_prices_on_tickets}.to change(subject, :total).by(discount_amount)
    end
  end

  describe ".can_hold?" do
    let(:ticket) { FactoryGirl.build :ticket }
    let(:cart) { FactoryGirl.build :cart }

    it "should be able to hold another ticket" do
      cart.should be_can_hold ticket
    end
  end
end
