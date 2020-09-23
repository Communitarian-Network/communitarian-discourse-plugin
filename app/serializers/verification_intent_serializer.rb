# frozen_string_literal: true

class VerificationIntentSerializer < ApplicationSerializer
  attributes :id, :status, :error, :full_name, :verification_url, :billing_address, :zipcode

  def id
    object[:id]
  end

  def status
    object[:status]
  end

  def error
    identity_document[:details]
  end

  def full_name
    [
      person_details[:first_name],
      person_details[:last_name]
    ].join(" ").strip
  end

  def verification_url
    object.dig(:next_action, :redirect_to_url)
  end

  def billing_address
    identity_billing_address || "unknown"
  end

  def zipcode
    person_details.dig(:address, :postal_code) || "unknown"
  end

  private

  def identity_billing_address
    person_details[:address].to_h.slice(:city, :country).values.reject(&:blank?).join(", ").presence
  end

  def person_details
    @person_details ||= identity_document[:person_details].to_h
  end

  def identity_document
    @identity_document ||= object.dig(:verification_reports, :identity_document).to_h
  end
end
