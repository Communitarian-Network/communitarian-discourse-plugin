# frozen_string_literal: true

module Communitarian
  class ResolutionsController < ::ApplicationController
    requires_plugin Communitarian

    before_action :ensure_logged_in

    def create
      manager = NewPostManager.new(current_user, permitted_params)

      result = manager.perform
      json = serialize_data(result, NewPostResultSerializer, root: false)
      render json: json, status: result.success? ? :created : :unprocessable_entity
    end

    private

    def permitted_params
      default_params.merge(resolution_params).with_indifferent_access
    end

    def resolution_params
      params.permit(:id, :raw, :title, :category, :composer_open_duration_msecs, :typing_duration_msecs)
    end

    def default_params
      {
        archetype: "regular",
        draft_key: "new_topic",
        is_resolution: true,
        is_warning: false,
        nested_post: true,
        shared_draft: false,
        unlist_topic: false
      }
    end
  end
end
