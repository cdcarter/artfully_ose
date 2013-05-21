class ExchangeOrder < Order 
  def self.location
    "Artful.ly"
  end
  
  def sell_tickets
 	end

  def purchase_action_class
    ExchangeAction
  end

  def revenue_applies_to(start_date, end_date)
    start_date < self.originally_sold_at && self.originally_sold_at < end_date
  end

  def ticket_details
    "exchanged tickets for " + super
  end
end