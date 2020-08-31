# frozen_string_literal: true

module Communitarian
  class PaymentIntentsController < ::ApplicationController
    requires_plugin Communitarian
    skip_before_action :verify_authenticity_token, :redirect_to_login_if_required, :check_xhr

    def create
      render_payment_intent_result(created_payment_intent)
    end

    private

    def created_payment_intent
      Communitarian::Stripe.new.created_payment_intent(payment_intent_params)
    end

    def render_payment_intent_result(result)
      if result.success?
        render_serialized(result.response, PaymentIntentSerializer, root: "payment_intent")
      else
        render_json_error result.error.message, status: :unprocessable_entity
      end
    end

    def payment_intent_params
      {
        amount: 100,
        currency: "usd",
        metadata: {
          email: email_parameter
        }
      }
    end

    def email_parameter
      params.require(:email)
    end
  end
end
