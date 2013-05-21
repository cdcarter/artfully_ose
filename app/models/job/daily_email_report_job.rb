class DailyEmailReportJob
  def perform(date=nil)

    date ||= 1.day.ago

    #
    # We have to go back two days here intentionally to account for orgs across different time zones
    # We'll re-select the correct orders in the respective jobs
    #
    org_ids = Order.csv_not_imported.after(date-1.day).before(DateTime.now).pluck(:organization_id).uniq
    Organization.where(:id => org_ids).receiving_sales_email.each do |org|
      tickets = DailyTicketReport.new(org, date)
      donations = DailyDonationReport.new(org, date)
      next if tickets.rows.empty? && donations.rows.empty? && tickets.exchange_rows.empty?
      ReportsMailer.daily(tickets, donations).deliver
    end
  end
end
