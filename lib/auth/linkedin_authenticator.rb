# frozen_string_literal: true

require 'auth/oauth2_authenticator'

class Auth::LinkedinAuthenticator < ::Auth::OAuth2Authenticator
  PLUGIN_NAME = 'oauth-linkedin'

  def name
    'linkedin'
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

  def after_authenticate(auth_token)
    result = Auth::Result.new

    oauth2_provider = auth_token[:provider]
    oauth2_uid = auth_token[:uid]
    data = auth_token[:info]
    result.email = email = data[:email]
    result.name = name = [data[:first_name], data[:last_name]].join(" ")
    result.username = username = [data[:first_name], data[:last_name], Time.current.to_i].join(".")[0, SiteSetting.max_username_length.to_i || 20]
    oauth2_user_info = Oauth2UserInfo.find_by(uid: oauth2_uid, provider: oauth2_provider)

    if !oauth2_user_info && @opts[:trusted] && user = User.find_by_email(email)
      oauth2_user_info = Oauth2UserInfo.create(uid: oauth2_uid,
                                               provider: oauth2_provider,
                                               name: name,
                                               email: email,
                                               user: user)
    end

    result.user = oauth2_user_info.try(:user)
    result.email_valid = @opts[:trusted]

    result.extra_data = {
      uid: oauth2_uid,
      provider: oauth2_provider
    }

    if result.user && email && (result.user.email != email)
      begin
        result.user.primary_email.update!(email: email)
        result.user.username.update!(username: username)
      rescue
        used_by = User.find_by_email(email)&.username
        Rails.logger.warn("FAILED to update email for #{user.username} to #{email} cause it is in use by #{used_by}")
      end
    end

    result
  end
end
