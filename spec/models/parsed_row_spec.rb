require 'spec_helper'

describe ParsedRow do

  context "benchmarking" do
    @headers = ["Email","Salutation","First name","Last name","Title","Company name","Address 1","Address 2","City","State","Zip","Country","Phone1 type","Phone1 number","Phone2 type","Phone2 number","Phone3 type","Phone3 number","Website","Twitter handle","Facebook url","Linked in url","Tags","Do not email"]
    @row     = ["MARION_MURRAY@lowe.name","Mrs.","Franz","","Human Accountability Assistant","Architecto","423 Haley Gardens","Suite 100","Gorczanyton","New Hampshire","23872-3243","USA","Home","1-748-037-9136 x77089","Cell","676.773.2996","Work","479-263-8897","hillsdeckow.name","franz.larkin","facebook.com/franz.larkin","linkedin.com/user/franz.larkin","rem|repudiandae","true"]
    Benchmark.bm(7) do |x|
      # x.report("100  :")   { (1..100).each { |i| ParsedRow.new(@headers, @row) } }
      # x.report("1000 :")   { (1..1000).each { |i| ParsedRow.new(@headers, @row) } }
      # x.report("10000:")   { (1..10000).each { |i| ParsedRow.new(@headers, @row) } }
      # x.report("20000:")   { (1..20000).each { |i| ParsedRow.new(@headers, @row) } }
    end
  end

  context "a person with their email and company specified" do
    before do
      @headers = [ "EMAIL", "Company" ]
      @row = [ "test@artful.ly", "Fractured Atlas" ]
      @person = ParsedRow.new(@headers, @row)
    end
  
    it "should have the correct email" do
      @person.email.should == "test@artful.ly"
    end
  
    it "should have the correct company" do
      @person.company.should == "Fractured Atlas"
    end
  
    it "should have a nil name" do
      @person.first.should be_nil
    end
  end
  
  context "a person with tags" do
    before do
      @headers = [ "Tags" ]
      @row = [ "one|two,three four" ]
      @person = ParsedRow.new(@headers, @row)
    end
  
    it "should correctly split on spaces, bars or commas" do
      @person.tags_list.should == %w( one two three-four )
    end
  end

  context "a person with a type" do
    before do
      @headers = [ "Person Type" ]
      @types = [ "individual", "corporation", "FOUNDATION", "GovernMENT", "nonsense", "other" ]
      @people = @types.map { |type| ParsedRow.new(@headers, [type]) }
    end
  
    it "should correctly load the enumerated types" do
      @people.map(&:person_type).should == %w( Individual Corporation Foundation Government Other Other )
    end
  end

  context "a person with do not email" do
    before do
      @headers = [ "Do not email" ]
      @rows = [ true, false ]
      @people = @rows.map { |do_not_email| ParsedRow.new(@headers, [do_not_email]) }
    end

    it "should correctly load do not email" do
      @people.map(&:do_not_email).should == [true, false]
    end
  end
end
