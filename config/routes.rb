# frozen_string_literal: true

require_dependency "communitarian_constraint"

Communitarian::Engine.routes.draw do
  post "/resolutions" => "resolutions#create", constraints: CommunitarianConstraint.new
  patch "/resolutions/:id" => "resolutions#update", constraints: CommunitarianConstraint.new
end
