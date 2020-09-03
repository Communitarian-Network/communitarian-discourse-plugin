# frozen_string_literal: true

# name: communitarian
# about: Common plugin with main features
# version: 0.2
# authors: Flatstack
# url: https://github.com/fs/communitarian-discourse-plugin

gem "omniauth-linkedin-oauth2", "1.0.0"
gem "stripe", "5.22.0"
gem "stripe_event", "2.3.1"
gem "interactor", "3.1.2"

require "stripe"

enabled_site_setting :communitarian_enabled

[
  "stylesheets/common/resolution-form.scss",
  "stylesheets/common/landing.scss",
  "stylesheets/common/communities-page.scss",
  "stylesheets/common/dialog-page.scss",
  "stylesheets/common/create-account-modal.scss",
  "stylesheets/common/community-page.scss",
  "stylesheets/common/dialog-list.scss",
  "stylesheets/common/dialog-list-page.scss",
  "stylesheets/common/dialog-list-item.scss",
  "stylesheets/common/resolution-list-item.scss",
  "stylesheets/common/page-header.scss",
  "stylesheets/common/community-action.scss",
  "stylesheets/linkedin-login.scss"
].each { |file| register_asset file }

register_svg_icon "fab-linkedin-in" if respond_to?(:register_svg_icon)

register_html_builder("server:before-head-close") do
  "<script src='https://js.stripe.com/v3/'></script>"
end

PLUGIN_NAME ||= "communitarian"

[
  "lib/communitarian/engine.rb",
  "lib/auth/linkedin_authenticator.rb",
  "lib/communitarian/stripe.rb"
].each { |path| load File.expand_path(path, __dir__) }

after_initialize do
  [
    "../app/models/communitarian/post_delay",
    "../app/models/communitarian/resolution",
    "../app/models/communitarian/unique_username",
    "../lib/guardian/category_guardian"
  ].each { |path| require File.expand_path(path, __FILE__) }

  Stripe.api_key = SiteSetting.communitarian_stripe_secret_key
  Stripe.api_version = '2020-03-02; identity_beta=v3'

  Topic.register_custom_field_type("is_resolution", :boolean)
  Category.register_custom_field_type("introduction_raw", :text)
  Category.register_custom_field_type("tenets_raw", :text)

  NewPostManager.add_handler(10) { |manager| Communitarian::PostDelay.new.call(manager) }

  # using Discourse "Topic Created" event to trigger a save.
  # `opts[]` is how you pass the data back from the frontend into Rails
  on(:topic_created) do |topic, opts, user|
    if opts[:is_resolution] != nil
      topic.custom_fields["is_resolution"] = opts[:is_resolution]
      topic.save_custom_fields(true)
    end
  end

  on(:category_created) do |category|
    about_post = category.topic.posts.first
    about = "#{category.custom_fields["introduction_raw"]}\n\n#{category.custom_fields["tenets_raw"]}\n\n#{about_post.raw}"
    about_post.update!(raw: about)
  end

  on(:post_created) do |post, opts|
    if opts[:is_resolution] != nil
      post.custom_fields["is_resolution"] = opts[:is_resolution]
      post.save_custom_fields(true)
    end
  end

  on(:post_created) do |post, _opts|
    Communitarian::Resolution.new(Communitarian::ResolutionSchedule.new).
      schedule_jobs(post)
  end

  on(:user_created) do |user|
    if user.oauth2_user_infos.blank?
      user.update!(username: Communitarian::UniqueUsername.new(user).to_s)
    end
  end

  add_to_serializer(:current_user, :homepage_id) { object.user_option.homepage_id }

  add_to_serializer(:topic_list, :dialogs, false) do
    object.dialogs.to_a.map do |dialog|
      TopicListItemSerializer.new(dialog, root: false, embed: :objects, scope: self.scope)
    end
  end

  add_to_serializer(:topic_list_item, :recent_resolution_post, false) do
    PostSerializer.new(object.recent_resolution_post, root: false, embed: :objects, scope: self.scope)
  end

  add_preloaded_topic_list_custom_field("is_resolution")

  require 'homepage_constraint'
  Discourse::Application.routes.prepend do
    root to: "communitarian/page#index", constraints: HomePageConstraint.new("home")
    get "/home" => "communitarian/page#index"
  end

  reloadable_patch do
    Topic.class_eval do
      has_one :recent_resolution_post, -> {
        joins(:_custom_fields).where(post_custom_fields: { name: :is_resolution }).order(post_number: :desc)
      }, class_name: "Post"
    end

    TopicQuery.class_eval do
      def self.public_valid_options
        @public_valid_options ||=
          %i(page
            before
            bumped_before
            topic_ids
            category
            order
            ascending
            min_posts
            max_posts
            status
            filter
            state
            search
            q
            group_name
            tags
            match_all_tags
            only_resolutions
            no_subcategories
            no_tags)
      end

      def list_dialogs
        create_list(:dialogs, {}, dialogs_results)
      end

      def dialogs_results(options = {})
        result = default_results(options)
        result = remove_muted_topics(result, @user) unless options && options[:state] == "muted"
        result = remove_muted_categories(result, @user, exclude: options[:category])
        result = remove_muted_tags(result, @user, options)
        result = apply_shared_drafts(result, get_category_id(options[:category]), options)
        result = apply_shared_drafts(result, get_category_id(options[:category]), options)
        result = result.where.not(id: TopicCustomField.where(name: :is_resolution).select(:topic_id))
        result
      end
    end

    # Return a list of suggested topics for a topic
    def list_suggested_for(topic, pm_params: nil)

      # Don't suggest messages unless we have a user, and private messages are
      # enabled.
      return if topic.private_message? &&
        (@user.blank? || !SiteSetting.enable_personal_messages?)

      builder = SuggestedTopicsBuilder.new(topic)

      pm_params = pm_params || get_pm_params(topic)

      # When logged in we start with different results
      if @user
        if topic.private_message?

          builder.add_results(new_messages(
            pm_params.merge(count: builder.results_left)
          )) unless builder.full?

          builder.add_results(unread_messages(
            pm_params.merge(count: builder.results_left)
          )) unless builder.full?

        else

          builder.add_results(
            unread_results(
              topic: topic,
              per_page: builder.results_left,
              max_age: SiteSetting.suggested_topics_unread_max_days_old
            ), :high
          )

          builder.add_results(new_results(topic: topic, per_page: builder.category_results_left)) unless builder.full?
        end
      end

      if !topic.private_message?
        builder.add_results(random_suggested(topic, builder.results_left, builder.excluded_topic_ids)) unless builder.full?
      end

      # add only_resolutions param
      params = { unordered: true, only_resolutions: false }
      if topic.private_message?
        params[:preload_posters] = true
      end
      create_list(:suggested, params, builder.results)
    end

    TopicQuery.results_filter_callbacks << Proc.new do |filter_name, result, user, options|
      options[:only_resolutions] ||= true

      if filter_name == :latest && options[:only_resolutions]
        result.where(id: TopicCustomField.where(name: :is_resolution).select(:topic_id))
      else
        result
      end
    end

    SuggestedTopicsBuilder.class_eval do
      def initialize(topic)
        @excluded_topic_ids = (TopicCustomField.where(name: :is_resolution).pluck(:topic_id) << topic.id).uniq
        @category_id = topic.category_id
        @category_topic_ids = Category.topic_ids
        @results = []
      end
    end
      
    Discourse.class_eval do
      def self.filters
        @filters ||= [:latest, :dialogs]
      end

      def self.anonymous_filters
        @anonymous_filters ||= [:latest, :top, :categories, :dialogs]
      end
    end

    TopicList.class_eval do
      attr_accessor :dialogs
    end

    ListController.class_eval do
      def category_default
        canonical_url "#{Discourse.base_url_no_prefix}#{@category.url}"
        view_method = @category.default_view
        view_method = 'latest' unless %w(latest top).include?(view_method)

        self.public_send(view_method, category: @category.id)
      end

      def latest(options = nil)
        filter = :latest
        list_opts = build_topic_list_options
        list_opts.merge!(options) if options
        user = list_target_user
        list_opts[:no_definitions] = true if params[:category].blank? && filter == :latest

        list = TopicQuery.new(user, list_opts).public_send("list_#{filter}")

        if guardian.can_create_shared_draft? && @category.present?
          if @category.id == SiteSetting.shared_drafts_category.to_i
            # On shared drafts, show the destination category
            list.topics.each do |t|
              t.includes_destination_category = true
            end
          else
            # When viewing a non-shared draft category, find topics whose
            # destination are this category
            shared_drafts = TopicQuery.new(
              user,
              category: SiteSetting.shared_drafts_category,
              destination_category_id: list_opts[:category]
            ).list_latest

            if shared_drafts.present? && shared_drafts.topics.present?
              list.shared_drafts = shared_drafts.topics
            end
          end
        end

        list.more_topics_url = construct_url_with(:next, list_opts)
        list.prev_topics_url = construct_url_with(:prev, list_opts)
        if Discourse.anonymous_filters.include?(filter)
          @description = SiteSetting.site_description
          @rss = filter

          # Note the first is the default and we don't add a title
          if (filter.to_s != current_homepage) && use_crawler_layout?
            filter_title = I18n.t("js.filters.#{filter.to_s}.title", count: 0)
            if list_opts[:category] && @category
              @title = I18n.t('js.filters.with_category', filter: filter_title, category: @category.name)
            else
              @title = I18n.t('js.filters.with_topics', filter: filter_title)
            end
            @title << " - #{SiteSetting.title}"
          elsif @category.blank? && (filter.to_s == current_homepage) && SiteSetting.short_site_description.present?
            @title = "#{SiteSetting.title} - #{SiteSetting.short_site_description}"
          end
        end

        list.dialogs = @category ? category_dialogs(category: @category.id, without_respond: true).topics.first(5) : []

        respond_with_list(list)
      end

      def category_dialogs(options = nil)
        without_respond = options ? options.delete(:without_respond) : false

        filter = :dialogs
        list_opts = build_topic_list_options
        list_opts.merge!(options) if options
        user = list_target_user
        list_opts[:no_definitions] = true if params[:category].blank? && filter == :latest

        list = TopicQuery.new(user, list_opts).public_send("list_#{filter}")

        if guardian.can_create_shared_draft? && @category.present?
          if @category.id == SiteSetting.shared_drafts_category.to_i
            # On shared drafts, show the destination category
            list.topics.each do |t|
              t.includes_destination_category = true
            end
          else
            # When viewing a non-shared draft category, find topics whose
            # destination are this category
            shared_drafts = TopicQuery.new(
              user,
              category: SiteSetting.shared_drafts_category,
              destination_category_id: list_opts[:category]
            ).list_latest

            if shared_drafts.present? && shared_drafts.topics.present?
              list.shared_drafts = shared_drafts.topics
            end
          end
        end

        list.more_topics_url = construct_url_with(:next, list_opts)
        list.prev_topics_url = construct_url_with(:prev, list_opts)

        return list if without_respond

        respond_with_list(list)
      end
    end
  end
end

auth_provider frame_width: 920,
              frame_height: 800,
              icon: "fab-linkedin-in",
              authenticator: Auth::LinkedinAuthenticator.new(
                "linkedin",
                trusted: true,
                auto_create_account: true
              )
