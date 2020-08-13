# frozen_string_literal: true

# name: communitarian
# about: Common plugin with main features
# version: 0.2
# authors: Flatstack
# url: https://github.com/fs/communitarian-discourse-plugin

gem "omniauth-linkedin-oauth2", "1.0.0"

%i[
  communitarian_enabled
  post_delay
  linkedin_enabled
].each { |setting| enabled_site_setting setting }

register_asset "stylesheets/common/resolution-form.scss"
register_asset "stylesheets/common/landing.scss"
register_asset "stylesheets/linkedin-login.scss"

register_svg_icon "fab-linkedin-in" if respond_to?(:register_svg_icon)

PLUGIN_NAME ||= "communitarian"

load File.expand_path("lib/communitarian/engine.rb", __dir__)
load File.expand_path("lib/auth/linkedin_authenticator.rb", __dir__)

after_initialize do
  [
    "../app/models/communitarian/post_delay",
    "../app/models/communitarian/resolution"
  ].each { |path| require File.expand_path(path, __FILE__) }

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
end

auth_provider frame_width: 920,
              frame_height: 800,
              icon: "fab-linkedin-in",
              authenticator: Auth::LinkedinAuthenticator.new(
                "linkedin",
                trusted: true,
                auto_create_account: true
              )
