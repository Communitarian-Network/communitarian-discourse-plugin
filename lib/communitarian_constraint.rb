# frozen_string_literal: true

class CommunitarianConstraint
  def matches?(request)
    SiteSetting.civil_dialogs_enabled
  end
end
