# frozen_string_literal: true

class VerificationSessionSerializer < ApplicationSerializer
  attributes :id, :status, :error, :full_name, :verification_url, :billing_address, :zipcode

  def id
    object[:id]
  end

  def status
    object[:status]
  end

  def error
    object[:last_error]&.reason
  end

  def full_name
    [
      verified_outputs[:first_name],
      verified_outputs[:last_name]
    ].join(" ").strip
  end

  def verification_url
    object[:url]
  end

  def billing_address
    identity_billing_address || "unknown"
  end

  def zipcode
    verified_address[:postal_code] || ""
  end

  private

  def identity_billing_address
    verified_address.slice(:city, :state, :country).values.reject(&:blank?).join(", ").presence
  end

  def verified_address
    @verified_address ||= verified_outputs[:address].to_h
  end

  def verified_outputs
    @verified_outputs ||= object[:verified_outputs].to_h
  end
end
