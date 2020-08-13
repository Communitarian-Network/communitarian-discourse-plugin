# frozen_string_literal: true

# name: communitarian
# about: Common plugin with main features
# version: 0.2
# authors: Flatstack
# url: https://github.com/fs/communitarian-discourse-plugin

gem "stripe", "5.22.0"
gem "stripe_event", "2.3.1"

require "stripe"

%i[
  communitarian_enabled
  post_delay
].each { |setting| enabled_site_setting setting }

register_asset "stylesheets/common/resolution-form.scss"
register_asset "stylesheets/common/landing.scss"

PLUGIN_NAME ||= "communitarian"

load File.expand_path("lib/communitarian/engine.rb", __dir__)
load File.expand_path("lib/communitarian/stripe.rb", __dir__)

after_initialize do
  [
    "../app/models/communitarian/post_delay",
    "../app/models/communitarian/resolution"
  ].each { |path| require File.expand_path(path, __FILE__) }

  Stripe.api_key = SiteSetting.communitarian_stripe_secret_key
  Stripe.api_version = '2020-03-02; identity_beta=v3'

  Topic.register_custom_field_type("is_resolution", :boolean)

  NewPostManager.add_handler(10) { |manager| Communitarian::PostDelay.new.call(manager) }

  # using Discourse "Topic Created" event to trigger a save.
  # `opts[]` is how you pass the data back from the frontend into Rails
  on(:topic_created) do |topic, opts, user|
    if opts[:is_resolution] != nil
      topic.custom_fields["is_resolution"] = opts[:is_resolution]
      topic.save_custom_fields(true)
    end
  end

  on(:post_created) do |post, _opts|
    Communitarian::Resolution.new(Communitarian::ResolutionSchedule.new).
      schedule_jobs(post)
  end

  add_to_serializer(:current_user, :homepage_id) { object.user_option.homepage_id }

  require 'homepage_constraint'
  Discourse::Application.routes.prepend do
    root to: "communitarian/page#index", constraints: HomePageConstraint.new("home")
    get "/home" => "communitarian/page#index"
  end
end
