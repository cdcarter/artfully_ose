module ArtfullyOseHelper
  include LinkHelper
  include ActionView::Helpers::NumberHelper

  def check_mark(size=nil, alt=nil)
    case size
      when :huge
        icon_tag('117-todo@2x', {:alt => alt})
      when :big
        icon_tag('117-todo', {:alt => alt})
      else
        "&#x2713;".html_safe
    end
  end

  def build_order_location(order)
    order.location
  end
  
  def channel_checkbox(channel)
    channel.to_s.eql?("storefront") ? "Storefront & Widgets" : channel.to_s.humanize
  end
  
  def channel_text(channel)
    channel.to_s.humanize
  end
  
  def build_action_path(target, action)
    action_path_name = action.new_record? ? "actions" : "actions"
    "#{target.class.name.downcase}_#{action_path_name}_path"
  end

  def time_ago_sentence(t)
    qualifier = t > Time.now ? "from now" : "ago"
    "#{time_ago_in_words(t)} #{qualifier}"
  end

  #
  # For use with the nav-pills to select an intem based on a current selection
  # Will protect against nil by using try on the object
  #
  # returns 'active' if selected_object.id = menu_object.id
  # 'unselected' otherwise
  #
  def get_selected_class(selected_object, menu_object)
    selected_object.try(:id) == menu_object.id ? "active" : "unselected"
  end
  
  #For use with Bootstraps icon %i classes
  def icon_link_to(text, href, icon, class_names, id, html_attributes={})
    s = "<a href='#{href}' class='#{class_names}' id='#{id}' "
    html_attributes.each do |k,v|
      s = s + " #{k}=#{v} "  
    end
    s = s + "><i class='#{icon}'></i> #{text}</a>"
    s.html_safe
  end
  
  #
  # just name the image, this method will prepend the path and append the .png
  # icon_tag('111-logo')
  #
  def icon_tag(img, options={})
    image_tag('glyphish/gray/' + img + '.png', options)
  end

  def time_zone_description(tz)
    ActiveSupport::TimeZone.create(tz)
  end
  
  #This is for the widget generator, DO NOT use anywhere else
  def fully_qualified_asset_path(asset)
    "#{asset_path(asset, :digest => false)}"
  end
  
  def events_to_options(selected_event_id = nil)
    @events = current_user.current_organization.events
    @events_array = @events.map { |event| [event.name, event.id] }
    @events_array.insert(0, ["", ""])
    options_for_select(@events_array, selected_event_id)
  end

  def contextual_menu(&block)
    menu = ContextualMenu.new(self)
    block.call(menu)
    menu.render_menu
  end

  def widget_script(event, organization)
    return <<-EOF
<script>
  $(document).ready(function(){
    artfully.configure({
      base_uri: '#{root_url}api/',
      store_uri: '#{root_url}store/'
    });
    #{render :partial => "widgets/event", :locals => { :event => event } unless event.nil? }
    #{render :partial => "widgets/donation", :locals => { :organization => organization } unless organization.nil? }
  });
<script>
    EOF
  end

  def amount_and_nongift(item)
    str = number_as_cents item.total_price
    str += " (#{number_as_cents item.nongift_amount} Non-deductible)" unless item.nongift_amount.nil?
    str
  end
  
  #This method will not prepend the $
  def number_to_dollars(cents)
    cents.to_i / 100.00
  end

  def number_as_cents(cents, options = {})
    number_to_currency(number_to_dollars(cents), options)
  end

  def sorted_us_state_names
    @sorted_us_state_names ||= us_states.keys.sort{|a, b| a <=> b}
  end

  def sorted_us_state_abbreviations
    @sorted_us_states ||= us_states.invert.keys.sort{|a, b| a <=> b}
  end

  def us_states
    {
      "Alabama"              =>"AL",
      "Alaska"               =>"AK",
      "American Samoa"       =>"AS",
      "Arizona"              =>"AZ",
      "Arkansas"             =>"AR",
      "California"           =>"CA",
      "Colorado"             =>"CO",
      "Connecticut"          =>"CT",
      "Delaware"             =>"DE",
      "District of Columbia" =>"DC",
      "Florida"              =>"FL",
      "Georgia"              =>"GA",
      "Guam"                 =>"GU",
      "Hawaii"               =>"HI",
      "Idaho"                =>"ID",
      "Illinois"             =>"IL",
      "Indiana"              =>"IN",
      "Iowa"                 =>"IA",
      "Kansas"               =>"KS",
      "Kentucky"             =>"KY",
      "Louisiana"            =>"LA",
      "Maine"                =>"ME",
      "Marshall Islands"     =>"MH",
      "Maryland"             =>"MD",
      "Massachusetts"        =>"MA",
      "Michigan"             =>"MI",
      "Micronesia"           =>"FM",
      "Minnesota"            =>"MN",
      "Mississippi"          =>"MS",
      "Missouri"             =>"MO",
      "Montana"              =>"MT",
      "Nebraska"             =>"NE",
      "Nevada"               =>"NV",
      "New Hampshire"        =>"NH",
      "New Jersey"           =>"NJ",
      "New Mexico"           =>"NM",
      "New York"             =>"NY",
      "North Carolina"       =>"NC",
      "North Dakota"         =>"ND",
      "Ohio"                 =>"OH",
      "Oklahoma"             =>"OK",
      "Oregon"               =>"OR",
      "Palau"                =>"PW",
      "Pennsylvania"         =>"PA",
      "Rhode Island"         =>"RI",
      "Puerto Rico"          =>"PR",
      "South Carolina"       =>"SC",
      "South Dakota"         =>"SD",
      "Tennessee"            =>"TN",
      "Texas"                =>"TX",
      "Utah"                 =>"UT",
      "Vermont"              =>"VT",
      "Virgin Islands"       =>"VI",
      "Virginia"             =>"VA",
      "Washington"           =>"WA",
      "Wisconsin"            =>"WI",
      "West Virginia"        =>"WV",
      "Wyoming"              =>"WY"
    }
  end

  def verb_for_save(record)
    record.new_record? ? "Create" : "Update"
  end

  def select_event_for_sales_search events, event_id, default
    options =
      [
        content_tag(:option, " --- All Events --- ", :value => ""),
        content_tag(:option, "", :value => ""),
        options_from_collection_for_select(events, :id, :name, default)
      ].join

    select_tag event_id, raw(options), :class => "span2"
  end

  def select_show_for_sales_search shows, show_id, default
    options =
      [
        content_tag(:option, " --- All Shows --- ", :value => ""),
        content_tag(:option, "", :value => ""),
        shows.map do |show|
          selected = "selected" if show.id == default.to_i
          content_tag(:option, l(show.datetime_local_to_event), :value => show.id, :selected => selected)
        end.join
      ].join

    select_tag show_id, raw(options), :class => "span3"
  end

  def nav_dropdown(text, link='#')
    link_to ERB::Util.html_escape(text) + ' <b class="caret"></b>'.html_safe, link, :class => 'dropdown-toggle', 'data-toggle' => 'dropdown'
  end
  
  def bootstrapped_type(type)
    case type
    when :notice then "alert alert-info"
    when :success then "alert alert-success"
    when :error then "alert alert-error"
    when :alert then "alert alert-error"
    end
  end

  def link_to_remove_fields(name, f)
    f.hidden_field(:_destroy) + link_to(name, "#", :onclick => "remove_fields(this); return false;")
  end
  
  def link_to_add_fields(name, f, association, view_path = '', additional_javascript=nil)
    new_object = f.object.class.reflect_on_association(association).klass.new
    fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      view_path = view_path + '/' unless view_path.blank?
      template_path = view_path + association.to_s.singularize + "_fields"
      render(template_path, :f => builder)
    end
    link_to name, "#", :onclick => "add_fields(this, \"#{association}\", \"#{escape_javascript(fields)}\"); #{additional_javascript} return false;"
  end
  
  def ticket_seller_name(ticket)
  end
  
  def credit_card_message
  end
  
  def date_field_tag(name, value = nil, options = {})
    text_field_tag(name, value, options.stringify_keys.update("type" => "date"))
  end
  
  def datetime_field_tag(name, value = nil, options = {})
    text_field_tag(name, value, options.stringify_keys.update("type" => "datetime"))
  end
end
