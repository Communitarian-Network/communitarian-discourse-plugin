# frozen_string_literal: true

# name: communitarian
# about: Common plugin with main features
# version: 0.2
# authors: Flatstack
# url: https://github.com/fs/communitarian-discourse-plugin

gem "stripe", "5.22.0"
gem "stripe_event", "2.3.1"

require "stripe"

%i[
  communitarian_enabled
  post_delay
].each { |setting| enabled_site_setting setting }

[
  "stylesheets/common/resolution-form.scss",
  "stylesheets/common/landing.scss",
  "stylesheets/common/communities-page.scss",
  "stylesheets/common/community-page.scss",
  "stylesheets/common/dialog-list.scss",
  "stylesheets/common/dialog-list-item.scss"
].each { |file| register_asset file }

PLUGIN_NAME ||= "communitarian"

load File.expand_path("lib/communitarian/engine.rb", __dir__)
load File.expand_path("lib/communitarian/stripe.rb", __dir__)

after_initialize do
  [
    "../app/models/communitarian/post_delay",
    "../app/models/communitarian/resolution"
  ].each { |path| require File.expand_path(path, __FILE__) }

  Stripe.api_key = SiteSetting.communitarian_stripe_secret_key
  Stripe.api_version = '2020-03-02; identity_beta=v3'

  Topic.register_custom_field_type("is_resolution", :boolean)

  NewPostManager.add_handler(10) { |manager| Communitarian::PostDelay.new.call(manager) }

  # using Discourse "Topic Created" event to trigger a save.
  # `opts[]` is how you pass the data back from the frontend into Rails
  on(:topic_created) do |topic, opts, user|
    if opts[:is_resolution] != nil
      topic.custom_fields["is_resolution"] = opts[:is_resolution]
      topic.save_custom_fields(true)
    end
  end

  on(:post_created) do |post, opts|
    if opts[:is_resolution] != nil
      post.custom_fields["is_resolution"] = opts[:is_resolution]
      post.save_custom_fields(true)
    end
    Communitarian::Resolution.new(Communitarian::ResolutionSchedule.new).
      schedule_jobs(post)
  end

  add_to_serializer(:current_user, :homepage_id) { object.user_option.homepage_id }

  add_to_serializer(:topic_list, :dialogs, false) do
    object.dialogs.map do |dialog|
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

    TopicQuery.results_filter_callbacks << Proc.new do |filter_name, result, user, options|
      if filter_name == :latest
        result.where(id: TopicCustomField.where(name: :is_resolution).select(:topic_id))
      else
        result
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

        list.dialogs = @category ? dialogs(category: @category.id).topics.first(5) : []

        respond_with_list(list)
      end

      def dialogs(options = nil)
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

        list.draft_key = Draft::NEW_TOPIC
        list.draft_sequence = DraftSequence.current(current_user, Draft::NEW_TOPIC)
        list.draft = Draft.get(current_user, list.draft_key, list.draft_sequence) if current_user
        list
      end
    end
  end
end
