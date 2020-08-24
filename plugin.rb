# frozen_string_literal: true

# name: communitarian
# about: Common plugin with main features
# version: 0.2
# authors: Flatstack
# url: https://github.com/fs/communitarian-discourse-plugin

gem "omniauth-linkedin-oauth2", "1.0.0"
gem "stripe", "5.22.0"
gem "stripe_event", "2.3.1"

require "stripe"

%i[
  communitarian_enabled
  post_delay
  linkedin_enabled
].each { |setting| enabled_site_setting setting }

[
  "stylesheets/common/resolution-form.scss",
  "stylesheets/common/landing.scss",
  "stylesheets/common/communities-page.scss",
  "stylesheets/linkedin-login.scss"
].each { |file| register_asset file }

register_svg_icon "fab-linkedin-in" if respond_to?(:register_svg_icon)

PLUGIN_NAME ||= "communitarian"

[
  "lib/communitarian/engine.rb",
  "lib/auth/linkedin_authenticator.rb",
  "lib/communitarian/stripe.rb",
  "lib/guardian/category_guardian.rb"
].each { |path| load File.expand_path(path, __dir__) }

after_initialize do
  [
    "../app/models/communitarian/post_delay",
    "../app/models/communitarian/resolution",
    "../app/models/communitarian/unique_username",
    "../lib/guardian/category_guardian"
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

  on(:user_created) do |user|
    if user.oauth2_user_infos.blank?
      user.update!(username: Communitarian::UniqueUsername.new(user).to_s)
    end
  end

  add_to_serializer(:current_user, :homepage_id) { object.user_option.homepage_id }

  require 'homepage_constraint'
  Discourse::Application.routes.prepend do
    root to: "communitarian/page#index", constraints: HomePageConstraint.new("home")
    get "/home" => "communitarian/page#index"
  end
end

auth_provider frame_width: 920,
              frame_height: 800,
              icon: "fab-linkedin-in",
              authenticator: Auth::LinkedinAuthenticator.new(
                "linkedin",
                trusted: true,
                auto_create_account: true
              )
