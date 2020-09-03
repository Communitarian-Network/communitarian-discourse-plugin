# frozen_string_literal: true

class PaymentIntentSerializer < ApplicationSerializer
  attributes :client_secret

  def client_secret
    object.client_secret
  end
end
