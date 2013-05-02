class ExchangeOrder < Order 
  def self.location
    "Artful.ly"
  end
  
  def sell_tickets
 	end

  def purchase_action_class
    ExchangeAction
  end

  def ticket_details
    "exchanged tickets for " + super
  end
end