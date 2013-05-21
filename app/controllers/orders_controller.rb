class OrdersController < ArtfullyOseController
  def index
    authorize! :manage, Order
    request.format = :csv if params[:commit] == "Download"
    if params[:search]
      @results = search(params[:search]).sort{|a,b| b.created_at <=> a.created_at }
      if @results.length == 1
        redirect_to order_path(@results.first.id)
      end
    else
      @results = current_organization.orders.includes(:person, :items).all.sort{|a,b| b.created_at <=> a.created_at }
    end
    respond_to do |format|
      format.html { @results = @results.paginate(:page => params[:page], :per_page => 25) }
      format.csv do
        filename = "Artfully-Orders-Export-#{DateTime.now.strftime("%m-%d-%y")}.csv"
        send_data @results.to_comma, :filename => filename, :type => "text/csv", :disposition => "attachment"
      end
    end
  end

  def show
    @order = Order.includes(:items => :discount).find(params[:id])
    authorize! :view, @order
    @person = Person.find(@order.person_id)
    @total = @order.total
  end

  def update
    @order = Order.find(params[:id])
    authorize! :manage, Order

    if @order.update_attributes(:notes => params[:order][:notes])
      flash[:success] = "Successfully updated order #{@order.id}."
    else
      flash[:error] = "Could not update order #{@order.id}."
    end
    redirect_to order_path(@order)
  end

  def resend
    authorize! :view, Order
    @order = Order.find(params[:id])
    OrderMailer.delay.confirmation_for(@order)
    
    flash[:notice] = "A copy of the order receipt has been sent to #{@order.person.email}"
    redirect_to order_url(@order)
  end

  def sales
    authorize! :view, Order

    @organization = current_organization
    @event = Event.find_by_id(params[:event_id]) if params[:event_id].present?
    @events = @organization.events_with_sales
    @show = @event.shows.find_by_id(params[:show_id]) if @event && params[:show_id].present?
    @shows = @event.shows_with_sales(@organization) if @event
    request.format = :csv if params[:commit] == "Download"

    search_terms = {
      :start        => params[:start],
      :stop         => params[:stop],
      :organization => @organization,
      :event        => @event,
      :show         => @show
    }

    @search = SaleSearch.new(search_terms) do |results|
      respond_to do |format|
        format.html { results.paginate(:page => params[:page], :per_page => 25) }
        format.csv do
          filename = "Artfully-Ticket-Sales-Export-#{DateTime.now.strftime("%m-%d-%y")}.csv"
          csv_string = results.collect(&:tickets).flatten.to_comma(:ticket_sale)
          send_data csv_string, :filename => filename, :type => "text/csv", :disposition => "attachment"
        end
      end
    end
  end

  private

  def search(query)
    Order.search_index(query, current_user.current_organization)
  end

end
