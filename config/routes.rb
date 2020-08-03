require_dependency "communitarian_constraint"

Communitarian::Engine.routes.draw do
  get "/admin/plugins/resolutions" => "admin/plugins#index", constraints: AdminConstraint.new
  post "/resolutions" => "resolutions#create", constraints: CommunitarianConstraint.new
end

Discourse::Application.routes.append do
  mount ::Communitarian::Engine, at: "resolutions"
end
