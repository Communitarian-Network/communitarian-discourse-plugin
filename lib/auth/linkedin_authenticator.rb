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
    address = parse_billing_address(data.dig(:address, :localized))

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

    if result.user && (result.user.email != email)
      ActiveRecord::Base.transaction do
        update_billing_address(result.user, address)
        update_email(result.user, email)
        update_username(result.user, username)
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
                      }, scope: 'r_fullprofile'
  end

  def enabled?
    SiteSetting.linkedin_enabled
  end

  private

  def update_email(user, email)
    if email
      begin
        user.primary_email.update!(email: email)
      rescue
        used_by = User.find_by_email(email)&.username
        Rails.logger.warn("FAILED to update email for #{user.username} to #{email} cause it is in use by #{used_by}")
      end
    end
  end

  def update_billing_address(user, address)
    if address
      begin
        UserCustomField.find_or_create_by(user_id: user.id, name: :user_field_123001).update(value: address)
      rescue
        Rails.logger.warn("FAILED to update billing address for #{user.username}")
      end
    end
  end

  def update_username(user, username)
    if username && (user.username != username)
      begin
        user.username.update!(username: username)
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

  def parse_billing_address(address = {})
    address.slice(:en, :en_US).values.first || address.values.first || "unknown"
  end
end
