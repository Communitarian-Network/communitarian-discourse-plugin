# frozen_string_literal: true

module Communitarian
  class VerificationIntentsController < ::ApplicationController
    requires_plugin Communitarian
    skip_before_action :verify_authenticity_token, :redirect_to_login_if_required
    skip_before_action :check_xhr, only: %i(show)
    before_action :ensure_not_logged_in, only: %i(show)

    def create
      session[:signup_data] = Marshal.dump(permitted_params)

      render_verification_intent_result(created_verification_intent)
    end

    def show
      preloaded_data = Marshal.load(session[:signup_data]).merge(user_fields: [{ 123001 => billing_address }])
      respond_to do |format|
        format.html do
          store_preloaded("signupData", MultiJson.dump(preloaded_data))
          render "default/empty"
        end
        format.json do
          render_verification_intent_result(verification_intent)
        end
      end
    end

    private

    def verification_intent
      @verification_intent ||= Communitarian::Stripe.new.get_verification_intent(params[:id])
    end

    def created_verification_intent
      @created_verification_intent ||= Communitarian::Stripe.new.created_verification_intent(verification_intent_params)
    end

    def verification_intent_params
      {
        return_url: URI.unescape(communitarian_verification_intent_url("{VERIFICATION_INTENT_ID}")),
        refresh_url: request.origin,
        requested_verifications: ["identity_document"],
        person_data: person_data_params,
        metadata: metadata_params
      }
    end

    def render_verification_intent_result(result)
      if result.success?
        render_serialized(result.response, VerificationIntentSerializer, root: "verification_intent")
      else
        render_json_error result.error.message, status: :unprocessable_entity
      end
    end

    def ensure_not_logged_in
      return redirect_to "/" if current_user
    end

    def person_data_params
      params.permit(:email).to_h
    end

    def metadata_params
      params.permit(:username).to_h
    end

    def permitted_params
      params.permit(:username, :email, :password, :password_confirmation, :challenge, :invite_code)
    end

    def identity_billing_address
      verification_intent.response
        .dig(:verification_reports, :identity_document, :person_details, :address)
        .try(:select) { |key, _| [:city, :country, :postal_code].include?(key) }
    end

    def billing_address
      return "unknown" unless identity_billing_address.present?

      identity_billing_address.values.reject(&:blank?).join(", ")
    end
  end
end
