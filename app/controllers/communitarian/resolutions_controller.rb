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

    def update
      params = permitted_params

      post = Post.where(id: params[:id])
      post = post.with_deleted if guardian.is_staff?
      post = post.first

      raise Discourse::NotFound if post.blank?

      post.image_sizes = params[:image_sizes] if params[:image_sizes].present?

      if !guardian.public_send("can_edit?", post) &&
         post.user_id == current_user.id &&
         post.edit_time_limit_expired?(current_user)

        return render_json_error(I18n.t('too_late_to_edit'))
      end

      guardian.ensure_can_edit!(post)

      changes = {
        raw: params[:raw],
        edit_reason: params[:edit_reason]
      }

      # to stay consistent with the create api, we allow for title & category changes here
      if post.is_first_post?
        changes[:title] = params[:title] if params[:title]
        changes[:category_id] = params[:category_id] if params[:category_id]

        if changes[:category_id] && changes[:category_id].to_i != post.topic.category_id.to_i
          category = Category.find_by(id: changes[:category_id])
          if category || (changes[:category_id].to_i == 0)
            guardian.ensure_can_move_topic_to_category!(category)
          else
            return render_json_error(I18n.t('category.errors.not_found'))
          end
        end
      end

      # We don't need to validate edits to small action posts by staff
      opts = {}
      if post.post_type == Post.types[:small_action] && current_user.staff?
        opts[:skip_validations] = true
      end

      topic = post.topic
      topic = Topic.with_deleted.find(post.topic_id) if guardian.is_staff?

      revisor = PostRevisor.new(post, topic)
      revisor.revise!(current_user, changes, opts)

      return render_json_error(post) if post.errors.present?
      return render_json_error(topic) if topic.errors.present?

      post_serializer = PostSerializer.new(post, scope: guardian, root: false)
      post_serializer.draft_sequence = DraftSequence.current(current_user, topic.draft_key)
      link_counts = TopicLink.counts_for(guardian, topic, [post])
      post_serializer.single_post_link_counts = link_counts[post.id] if link_counts.present?

      result = { post: post_serializer.as_json }
      if revisor.category_changed.present?
        result[:category] = BasicCategorySerializer.new(revisor.category_changed, scope: guardian, root: false).as_json
      end

      render_json_dump(result)
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
