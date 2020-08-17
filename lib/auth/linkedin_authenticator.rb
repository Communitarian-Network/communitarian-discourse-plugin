# frozen_string_literal: true

require 'auth/oauth2_authenticator'

class Auth::LinkedinAuthenticator < ::Auth::OAuth2Authenticator
  PLUGIN_NAME = 'oauth-linkedin'

  def name
    'linkedin'
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    oauth2_provider = auth_token[:provider]
    oauth2_uid = auth_token[:uid]
    data = auth_token[:info]
    result.email = email = data[:email]
    result.name = name = [data[:first_name], data[:last_name]].join(" ")
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

    result.username = username = generate_username(data, result.user)

    if result.user
      ActiveRecord::Base.transaction do
        update_email(result, email)
        update_username(result, username)
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

  private

  def update_email(result, email)
    if email && (result.user.email != email)
      begin
        result.user.primary_email.update!(email: email)
      rescue
        used_by = User.find_by_email(email)&.username
        Rails.logger.warn("FAILED to update email for #{user.username} to #{email} cause it is in use by #{used_by}")
      end
    end
  end

  def update_username(result, username)
    if username && (result.user.username != username)
      begin
        result.user.username.update!(username: username)
      rescue
        used_by = User.find_by_username(username)&.username
        Rails.logger.warn("FAILED to update username for #{user.username} to #{username} cause it is in use by #{used_by}")
      end
    end
  end

  def generate_username(data, user)
    username_max_length = SiteSetting.max_username_length.to_i
    username_id = user&.id || Time.current.to_i

    [data[:first_name], data[:last_name], username_id].join(".")[0, username_max_length]
  end
end
