# frozen_string_literal: true

module Communitarian
  class Engine < ::Rails::Engine
    engine_name "Communitarian".freeze
    isolate_namespace Communitarian

    config.after_initialize do
      Discourse::Application.routes.append do
        mount ::Communitarian::Engine, at: "/communitarian"
      end
    end
  end
end
