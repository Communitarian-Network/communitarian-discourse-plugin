# frozen_string_literal: true

class CommunitarianConstraint
  def matches?(request)
    SiteSetting.communitarian_enabled
  end
end
