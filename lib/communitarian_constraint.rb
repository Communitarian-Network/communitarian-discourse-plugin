class CommunitarianConstraint
  def matches?(request)
    SiteSetting.communitarian_enabled
  end
end
