# frozen_string_literal: true

module Communitarian
  class UsersController < ::ApplicationController
    requires_plugin Communitarian

    before_action :respond_to_suspicious_request, only: :new
    skip_before_action :verify_authenticity_token, :redirect_to_login_if_required

    def new
      params.require(:email)
      params.require(:invite_code) if SiteSetting.require_invite_code
      params.permit(:user_fields)

      unless SiteSetting.allow_new_registrations
        return fail_with("login.new_registrations_disabled")
      end

      if params[:password] && params[:password].length > User.max_password_length
        return fail_with("login.password_too_long")
      end

      if params[:email].length > 254 + 1 + 253
        return fail_with("login.email_too_long")
      end

      if SiteSetting.require_invite_code && SiteSetting.invite_code.strip.downcase != params[:invite_code].strip.downcase
        return fail_with("login.wrong_invite_code")
      end

      if clashing_with_existing_route?(params[:username]) || User.reserved_username?(params[:username])
        return fail_with("login.reserved_username")
      end

      params[:locale] ||= I18n.locale unless current_user

      new_user_params = user_params.except(:timezone)

      user = User.where(staged: true).with_email(new_user_params[:email].strip.downcase).first

      if user
        user.active = false
        user.unstage!
      end

      user ||= User.new
      user.attributes = new_user_params
      user.username = "user.#{Time.current.to_i}"

      # Handle API approval and
      # auto approve users based on auto_approve_email_domains setting
      if user.approved? || EmailValidator.can_auto_approve_user?(user.email)
        ReviewableUser.set_approved_fields!(user, current_user)
      end

      # Handle custom fields
      user_fields = UserField.all
      if user_fields.present?
        field_params = params[:user_fields] || {}
        fields = user.custom_fields

        user_fields.each do |f|
          field_val = field_params[f.id.to_s]
          if field_val.blank?
            return fail_with("login.missing_user_field") if f.required?
          else
            fields["#{User::USER_FIELD_PREFIX}#{f.id}"] = field_val[0...UserField.max_length]
          end
        end

        user.custom_fields = fields
      end

      authentication = UserAuthenticator.new(user, session)

      if !authentication.has_authenticator? && !SiteSetting.enable_local_logins && !(current_user&.admin? && is_api?)
        return render body: nil, status: :forbidden
      end

      authentication.start

      if authentication.email_valid? && !authentication.authenticated?
        # posted email is different that the already validated one?
        return fail_with('login.incorrect_username_email_or_password')
      end

      # just assign a password if we have an authenticator and no password
      # this is the case for Twitter
      user.password = SecureRandom.hex if user.password.blank? && authentication.has_authenticator?

      if user.valid?
        render json: { success: true }
      else
        errors = user.errors.to_hash
        errors[:email] = errors.delete(:primary_email) if errors[:primary_email]

        render json: {
          success: false,
          message: I18n.t(
            'login.errors',
            errors: user.errors.full_messages.join("\n")
          ),
          errors: errors,
          values: {
            name: user.name,
            username: user.username,
            email: user.primary_email&.email
          },
          is_developer: UsernameCheckerService.is_developer?(user.email)
        }, status: :unprocessable_entity
      end
    rescue ActiveRecord::StatementInvalid
      render json: {
        success: false,
        message: I18n.t("login.something_already_taken")
      }, status: :unprocessable_entity
    end

    def billing_address
      geo = get_geo_info(params["zipcode"])

      address = [geo.city&.gsub(/\W+|\d+/, ""), geo.state_name, geo.country_code].reject(&:blank?).join(", ").presence || "unknown"

      if geo.success && params["zipcode"] == geo.zip
        render json: { success: true, values: { address: address } }
      else
        render json: {
          success: false,
          values: { address: address },
          message: I18n.t("login.invalid_zipcode")
        }, status: :unprocessable_entity
      end

      rescue ArgumentError, Geokit::Geocoders::GeocodeError
        render json: {
          success: false,
          message: I18n.t("login.invalid_zipcode")
        }, status: :unprocessable_entity
    end

    private

    def get_geo_info(zipcode = nil)
      us_geo = Geokit::Geocoders::GeonamesGeocoder.geocode("United States, #{zipcode}")

      us_geo.success? && zipcode == us_geo.zip ? us_geo : Geokit::Geocoders::GeonamesGeocoder.geocode(zipcode)
    end

    def fail_with(key)
      render json: { success: false, message: I18n.t(key) }, status: :unprocessable_entity
    end

    def clashing_with_existing_route?(username)
      normalized_username = User.normalize_username(username)
      http_verbs = %w[GET POST PUT DELETE PATCH]
      allowed_actions = %w[show update destroy]

      http_verbs.any? do |verb|
        begin
          path = Rails.application.routes.recognize_path("/u/#{normalized_username}", method: verb)
          allowed_actions.exclude?(path[:action])
        rescue ActionController::RoutingError
          false
        end
      end
    end

    def respond_to_suspicious_request
      if suspicious?(params)
        render json: {
          success: true,
          active: false,
          message: I18n.t("login.activate_email", email: params[:email])
        }
      end
    end

    def suspicious?(params)
      return false if current_user && is_api? && current_user.admin?
      honeypot_or_challenge_fails?(params) || SiteSetting.invite_only?
    end

    def honeypot_or_challenge_fails?(params)
      return false if is_api?
      params[:password_confirmation] != honeypot_value ||
      params[:challenge] != challenge_value.try(:reverse)
    end

    def honeypot_value
      secure_session[::UsersController::HONEYPOT_KEY] ||= SecureRandom.hex
    end

    def challenge_value
      secure_session[::UsersController::CHALLENGE_KEY] ||= SecureRandom.hex
    end

    def user_params
      permitted = [
        :name,
        :email,
        :password,
        :username,
        :title,
        :date_of_birth,
        :muted_usernames,
        :ignored_usernames,
        :theme_ids,
        :locale,
        :bio_raw,
        :location,
        :website,
        :dismissed_banner_key,
        :profile_background_upload_url,
        :card_background_upload_url,
        :primary_group_id,
        :featured_topic_id
      ]

      editable_custom_fields = User.editable_user_custom_fields(by_staff: current_user.try(:staff?))
      permitted << { custom_fields: editable_custom_fields } unless editable_custom_fields.blank?
      permitted.concat UserUpdater::OPTION_ATTR
      permitted.concat UserUpdater::CATEGORY_IDS.keys.map { |k| { k => [] } }
      permitted.concat UserUpdater::TAG_NAMES.keys

      result = params
        .permit(permitted, theme_ids: [])
        .reverse_merge(
          ip_address: request.remote_ip,
          registration_ip_address: request.remote_ip
        )

      if !UsernameCheckerService.is_developer?(result['email']) &&
          is_api? &&
          current_user.present? &&
          current_user.admin?

        result.merge!(params.permit(:active, :staged, :approved))
      end

      modify_user_params(result)
    end

    # Plugins can use this to modify user parameters
    def modify_user_params(attrs)
      attrs
    end
  end
end
