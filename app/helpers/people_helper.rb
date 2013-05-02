module PeopleHelper  
  def link_to_person(person)
    link_to person, person
  end

  def person_avatar_with_fallback(person, size=50)
    # In development the default image will never appear.
    # (the url has to be publicly available in order for gravatar to fall back to it)
    # If you just want to see the default you can use 
    # image_tag('person-default-avatar.png')
    gravatar_image_tag(person.email, :alt => person.to_s, :gravatar => { :secure => true, :size => size, :default => full_image_url('person-default-avatar.png') })
  end

  def full_url(address, protocol='http://')
    if address.include?(protocol)
      address
    else
      "#{protocol}#{address}".squish
    end
  end

  def show_action_template(action)
    if lookup_context.exists?("show", "actions/#{action.action_type.downcase}", true)
      "actions/#{action.action_type.downcase}/show"
    else
      "actions/shared/show"
    end
  end

  def full_image_url(image)
    URI.join(root_url, image_path(image)).to_s
  end

  def action_type_button(action, type, verb, placeholder)
    classes = ['btn', 'action-type-button']
    classes << type
    classes << 'active' if action.action_type.downcase == type rescue nil
    content_tag(
      :button,
      content_tag(:span, verb.capitalize, :class => "#{type}-icon"),
      {:class => classes.join(' '), :type => 'button', 'data-action-type' => type, 'data-details-placeholder' => placeholder, 'data-subtypes' => Action.subtypes_by_type[type].to_json}
    )
  end
end