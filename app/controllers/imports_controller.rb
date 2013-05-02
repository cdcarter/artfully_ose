class ImportsController < ArtfullyOseController

  before_filter { authorize! :create, Import }
  before_filter :set_import_type

  def index
    @imports = organization.imports.order('created_at desc').all
  end

  def approve
    @import = organization.imports.find(params[:id])
    @import.approve!

    flash[:notice] = "Your file has been entered in the import queue. This process may take some time.  Reload this page to see progress or check back in a few minutes."
    redirect_to imports_path
  end

  def show
    @import = organization.imports.find(params[:id])

    #
    # Building an import preview was just murdering us. The problem is way down in Array.index in parsed_row.load_value.
    # Temporarily shutting it off.
    #
    # if @import.status == "pending"
    #   @parsed_rows = @import.parsed_rows.paginate(:page => params[:page], :per_page => 50)
    # end
    @people = Person.where(:import_id => @import.id).paginate(:page => params[:page], :per_page => 50) unless @import.id.nil?
  end

  def new
    if params[:bucket].present? && params[:key].present?      
      @import = Import.build(@type)
      @import.organization  = organization
      @import.s3_bucket     = params[:bucket]
      @import.s3_key        = params[:key]
      @import.s3_etag       = params[:etag]
      @import.status        = "caching"
      @import.user_id       = current_user.id
      @import.caching!
      redirect_to import_path(@import)
    else
      @import = Import.build(@type)
    end
  end

  def create
    @import = Import.build(@type)
    @import.user = current_user
    @import.organization = organization

    if @import.save
      redirect_to import_path(@import)
    else
      render :new
    end
  end

  def destroy
    @import = organization.imports.find(params[:id])
    @import.destroy
    redirect_to imports_path
  end

  def template   
    case @type
    when "events"
      fields = ParsedRow::EVENT_FIELDS
    when "people"
      fields = ParsedRow::PEOPLE_FIELDS
    when "donations"
      fields = ParsedRow::DONATION_FIELDS
    end
    
    columns = fields.map { |field, names| names.first }
    csv_string = CSV.generate { |csv| csv << columns }
    send_data csv_string, :filename => "Artfully-Import-Template.csv", :type => "text/csv", :disposition => "attachment"
  end

  protected

    def organization
      current_user.current_organization
    end
    
    def set_import_type
      #Cache import type to work around the direct to s3 upload
      session[:type] = params[:type] unless params[:type].blank?
      @type = (params[:type] || session[:type])
    end

end
