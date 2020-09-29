# frozen_string_literal: true

require_dependency "communitarian_constraint"

Communitarian::Engine.routes.draw do
  constraints CommunitarianConstraint.new do
    resources :resolutions, only: :create
    resources :verification_intents, only: %i(create show), as: :communitarian_verification_intents
    resources :payment_intents, only: :create, as: :communitarian_payment_intents
    resources :users, only: :new
    get "users/billing_address" => "users#billing_address"
  end
end
