class ExpireTicketJob < Struct.new(:ticket_ids)
  def perform
    ActiveRecord::Base.transaction do
      ticket_ids.each do |ticket_id|

        # Intentionally not resucuing from RecordNotFound here.  Trying to expire a ticket that doesn't exist 
        # is a truly exceptional condition,
        # best to rollback and blow up so we can figure out what went wrong.
        ticket = Ticket.find(ticket_id)
        expire_ticket(ticket)
      end
    end
  end

  def expire_ticket(ticket)
    ticket.cart_id = nil
    ticket.reset_price!
  end
end