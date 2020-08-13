# frozen_string_literal: true

require_dependency "communitarian_constraint"

Communitarian::Engine.routes.draw do
  constraints CommunitarianConstraint.new do
    resources :resolutions, only: %i[create]
  end
end
