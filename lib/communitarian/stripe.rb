# frozen_string_literal: true

module Communitarian
  class Stripe
    Error = Struct.new(:type, :message)

    attr_reader :success, :response, :error

    alias success? success

    def initialize
      @success = true
      @response = nil
      @error = nil
    end

    def created_verification_session(params)
      call_with_rescue do
        ::Stripe::Identity::VerificationSession.create(params)
      end
    end

    def get_verification_session(params = {})
      call_with_rescue do
        ::Stripe::Identity::VerificationSession.retrieve(params)
      end
    end

    def created_payment_intent(params)
      call_with_rescue do
        ::Stripe::PaymentIntent.create(params)
      end
    end

    protected

    def call_with_rescue(&block)
      @response = yield
      self
    rescue ::Stripe::StripeError => exc
      @success = false
      @error = Error.new(exc.class, exc.message)
      self
    end
  end
end
