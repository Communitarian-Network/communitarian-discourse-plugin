require_dependency "communitarian_constraint"

Communitarian::Engine.routes.draw do
  post '/resolutions' => 'resolutions#create', constraints: CommunitarianConstraint.new
end
