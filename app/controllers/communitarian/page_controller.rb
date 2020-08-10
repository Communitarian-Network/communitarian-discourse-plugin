# frozen_string_literal: true

module Communitarian
  class PageController < ::ApplicationController
    requires_plugin Communitarian

    def index
      render json: { title: "Hello world!" }
    end
  end
end
