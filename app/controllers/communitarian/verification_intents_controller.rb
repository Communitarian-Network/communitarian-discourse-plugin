# frozen_string_literal: true

module Communitarian
  class VerificationIntentsController < ::ApplicationController
    requires_plugin Communitarian
    skip_before_action :verify_authenticity_token
    skip_before_action :check_xhr, only: %i(show)
    before_action :ensure_not_logged_in, only: %i(show)

    rescue_from Stripe::StripeError do |exc|
      render_json_error exc.message, status: :unprocessable_entity
    end

    def create
      session[:signup_data] = Marshal.dump(permitted_params)

      render_serialized(created_verification_intent, VerificationIntentSerializer, root: "verification_intent")
    end

    def show
      respond_to do |format|
        format.html do
          store_preloaded("signupData", MultiJson.dump(Marshal.load(session[:signup_data])))
          render "default/empty"
        end
        format.json do
          render_serialized(verification_intent, VerificationIntentSerializer, root: "verification_intent")
        end
      end
    end

    private

    def verification_intent
      @verification_intent ||= Stripe::APIResource.request(
        :get,
        "/v1/identity/verification_intents/#{params[:id]}",
        {}
      ).first.data
    end

    def created_verification_intent
      @created_verification_intent ||= Stripe::APIResource.request(
        :post, "/v1/identity/verification_intents", verification_intent_params
      ).first.data
    end

    def verification_intent_params
      {
        return_url: URI.unescape(communitarin_verification_intent_url("{VERIFICATION_INTENT_ID}")),
        refresh_url: request.origin,
        requested_verifications: ["identity_document"],
        person_data: person_data_params,
        metadata: metadata_params
      }
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
      params.permit(
        :username, :email, :password, :password_confirmation,
        :challenge, :user_fields, :invite_code
      )
    end
  end
end
