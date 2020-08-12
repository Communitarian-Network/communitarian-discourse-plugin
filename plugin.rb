# frozen_string_literal: true

# name: communitarian
# about: Common plugin with main features
# version: 0.2
# authors: Flatstack
# url: https://github.com/fs/communitarian-discourse-plugin

gem "omniauth-linkedin-oauth2", "1.0.0"
require "auth/oauth2_authenticator"

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

class LinkedInAuthenticator < ::Auth::OAuth2Authenticator
  PLUGIN_NAME = 'oauth-linkedin'

  def name
    'linkedin'
  end

  def after_authenticate(auth_token)
    result = super

    if result.user && result.email && (result.user.email != result.email)
      begin
        result.user.primary_email.update!(email: result.email)
      rescue
        used_by = User.find_by_email(result.email)&.username
        Rails.logger.warn("FAILED to update email for #{user.username} to #{result.email} cause it is in use by #{used_by}")
      end
    end

    result
  end

  def register_middleware(omniauth)
    omniauth.provider :linkedin,
                      setup: lambda { |env|
                        strategy = env['omniauth.strategy']
                        strategy.options[:client_id] = SiteSetting.linkedin_client_id
                        strategy.options[:client_secret] = SiteSetting.linkedin_secret
                      }
  end

  def enabled?
    SiteSetting.linkedin_enabled
  end
end

auth_provider frame_width: 920,
              frame_height: 800,
              icon: "fab-linkedin-in",
              authenticator: LinkedInAuthenticator.new(
                "linkedin",
                trusted: true,
                auto_create_account: true
              )
