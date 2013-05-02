class GoAction < Action

  def show
    subject
  end
  
  def action_type
    "Go"
  end
  
  def verb
    "went"
  end

  def sentence
    #TODO: YUK
    if subject.is_a? Show
      #TODO: showtime, etc... needs to be printed on the details when go_action is created
      " attended #{show.event.name} on #{I18n.l show.datetime_local_to_event, :format => :short}"
    else
      " attended a show"
    end
  end
  
  def self.for(show, person, occurred_at=nil)
    GoAction.new.tap do |go_action|
      go_action.person = person
      go_action.subject = show
      go_action.details = "attended #{show.event}"
      go_action.organization = show.organization
      go_action.occurred_at = ( occurred_at.nil? ? show.datetime : occurred_at )
    end
  end

  def self.subtypes
    []
  end
end