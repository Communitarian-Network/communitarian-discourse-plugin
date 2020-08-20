# frozen_string_literal: true

require_dependency "communitarian_constraint"

Communitarian::Engine.routes.draw do
  constraints CommunitarianConstraint.new do
    resources :resolutions, only: :create
    resources :verification_intents, only: %i(create show), as: :communitarian_verification_intents
    resources :users, only: :new
  end
end
