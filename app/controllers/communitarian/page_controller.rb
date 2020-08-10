# frozen_string_literal: true

module Communitarian
  class PageController < ::ApplicationController
    requires_plugin Communitarian

    def index
      binding.pry
      render json: { name: "Hello world!" }
    end
  end
end
