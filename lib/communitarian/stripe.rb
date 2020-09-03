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

    def get_verification_intent(id, metadata = {})
      call_with_rescue do
        ::Stripe::APIResource.request(:get, "/v1/identity/verification_intents/#{id}", metadata).first.data
      end
    end

    def created_verification_intent(params)
      call_with_rescue do
        ::Stripe::APIResource.request(:post, "/v1/identity/verification_intents", params).first.data
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
