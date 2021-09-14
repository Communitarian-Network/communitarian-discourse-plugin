# frozen_string_literal: true

module Communitarian
  class VerificationSessionsController < ::ApplicationController
    requires_plugin Communitarian
    skip_before_action :verify_authenticity_token, :redirect_to_login_if_required
    skip_before_action :check_xhr, only: %i(show)
    before_action :ensure_not_logged_in, only: %i(show)

    def create
      session[:signup_data] = Marshal.dump(permitted_params)

      render_verification_session_result(created_verification_session)
    end

    def show
      respond_to do |format|
        format.html do
          store_preloaded("signupData", MultiJson.dump(Marshal.load(session[:signup_data])))
          render "default/empty"
        end
        format.json do
          render_verification_session_result(verification_session)
        end
      end
    end

    private

    def verification_session
      @verification_session ||= Communitarian::Stripe.new.get_verification_session(verification_session_params)
    end

    def created_verification_session
      @created_verification_session ||= Communitarian::Stripe.new.created_verification_session(new_verification_session_params)
    end

    def verification_session_params
      params.permit(:id).merge(expand: %w(verified_outputs)).to_h
    end

    def new_verification_session_params
      {
        type: "document",
        return_url: URI.unescape(communitarian_verification_sessions_url),
        metadata: metadata_params
      }
    end

    def render_verification_session_result(result)
      if result.success?
        render_serialized(result.response, VerificationSessionSerializer, root: "verification_session")
      else
        render_json_error result.error.message, status: :unprocessable_entity
      end
    end

    def ensure_not_logged_in
      return redirect_to "/" if current_user
    end

    def metadata_params
      params.permit(:email, :username).to_h
    end

    def permitted_params
      params.permit(:username, :email, :password, :password_confirmation, :challenge, :billing_address)
    end
  end
end
