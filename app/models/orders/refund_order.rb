class RefundOrder < Order
  include Unrefundable

  def self.location
    "Artful.ly"
  end

  def verb
    "Received refund"
  end
  
  def sell_tickets
  end

  def purchase_action_class
    RefundAction
  end

  def ticket_details
    "received refund for " + pluralize(num_tickets, "ticket")
  end
end