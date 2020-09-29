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
  "stylesheets/common/about-page.scss",
  "stylesheets/common/resolution-form.scss",
  "stylesheets/common/landing.scss",
  "stylesheets/common/empty-states.scss",
  "stylesheets/common/communities-page.scss",
  "stylesheets/common/dialog-page.scss",
  "stylesheets/common/create-account-modal.scss",
  "stylesheets/common/login-modal.scss",
  "stylesheets/common/header.scss",
  "stylesheets/common/forgot-password-modal.scss",
  "stylesheets/common/choose-verification-way-modal.scss",
  "stylesheets/common/payment-details-modal.scss",
  "stylesheets/common/verification-intents.scss",
  "stylesheets/common/activation-email.scss",
  "stylesheets/common/community-page.scss",
  "stylesheets/common/dialog-list.scss",
  "stylesheets/common/dialog-list-page.scss",
  "stylesheets/common/dialog-list-item.scss",
  "stylesheets/common/new-topic-dropdown.scss",
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

  Category.register_custom_field_type("introduction_raw", :text)
  Category.register_custom_field_type("tenets_raw", :text)

  NewPostManager.add_handler(10) { |manager| Communitarian::PostDelay.new.call(manager) }

  # using Discourse "Topic Created" event to trigger a save.
  # `opts[]` is how you pass the data back from the frontend into Rails
  on(:topic_created) do |topic, opts, user|
    topic.update_column(:is_resolution, true) if opts[:is_resolution]
  end

  on(:topic_created) do |topic, opts, _user|
    topic.tags.find_or_create_by(name: opts[:is_resolution] ? "resolution" : "dialogue")
  end

  on(:category_created) do |category|
    about_post = category.topic.posts.first
    revisor = PostRevisor.new(about_post, about_post.topic)
    about = category.custom_fields["introduction_raw"].presence || about_post.raw
    revisor.revise!(about_post.user, { raw: about }, skip_validations: true)
  end

  on(:post_created) do |post, opts|
    post.update_column(:is_resolution, true) if opts[:is_resolution]
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

  add_to_serializer(:topic_list_item, :recent_resolution_post, false) do
    return unless object.is_resolution?

    PostSerializer.new(object.recent_resolution_post, root: false, embed: :objects, scope: self.scope)
  end

  require 'homepage_constraint'
  Discourse::Application.routes.prepend do
    root to: "communitarian/page#index", constraints: HomePageConstraint.new("home")
    get "/home" => "communitarian/page#index"
  end

  reloadable_patch do
    TopicListSerializer.class_eval do
      has_many :dialogs, serializer: TopicListItemSerializer, embed: :objects

      def dialogs
        object.dialogs.to_a
      end
    end

    Topic.class_eval do
      has_one :recent_resolution_post, -> { where(is_resolution: true).order(post_number: :desc) }, class_name: "Post"
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
        result = result.where(is_resolution: false)
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
        result.includes(:recent_resolution_post).where(is_resolution: true)
      else
        result
      end
    end

    SuggestedTopicsBuilder.class_eval do
      def initialize(topic)
        @excluded_topic_ids = (Topic.where(is_resolution: true).ids << topic.id).uniq
        @category_id = topic.category_id
        @category_topic_ids = Category.topic_ids
        @results = []
      end
    end

    Discourse.class_eval do
      def self.filters
        @filters = [:latest, :unread, :new, :read, :posted, :bookmarks, :dialogs]
      end

      def self.anonymous_filters
        @anonymous_filters = [:latest, :top, :categories, :dialogs]
      end
    end

    TopicList.class_eval do
      attr_accessor :dialogs
    end

    User.class_eval do
      def billing_address
        UserCustomField.find_by(user_id: id, name: :user_field_123001)&.value
      end
    end

    About.class_eval do
      def title
        SiteSetting.about_title
      end
    end

    Category.class_eval do
      def create_category_definition
        return if skip_category_definition

        Topic.transaction do
          t = Topic.new(title: I18n.t("category.community_prefix", category: name), user: user, pinned_at: Time.now, category_id: id)
          t.skip_callbacks = true
          t.ignore_category_auto_close = true
          t.delete_topic_timer(TopicTimer.types[:close])
          t.save!(validate: false)
          update_column(:topic_id, t.id)
          post = t.posts.build(raw: description || post_template, user: user)
          post.save!(validate: false)
          update_column(:description, post.cooked) if description.present?

          t
        end
      end

      # If the name changes, try and update the category definition topic too if it's an exact match
      def rename_category_definition
        return unless topic.present?
        old_name = saved_changes.transform_values(&:first)["name"]
        if topic.title == I18n.t("category.community_prefix", category: old_name)
          topic.update_attribute(:title, I18n.t("category.community_prefix", category: name))
        end
      end
    end

    UsersController.class_eval do
      def account_created
        if current_user.present?
          if SiteSetting.enable_sso_provider && payload = cookies.delete(:sso_payload)
            return redirect_to(session_sso_provider_url + "?" + payload)
          elsif destination_url = cookies.delete(:destination_url)
            return redirect_to(destination_url)
          else
            return redirect_to(path('/'))
          end
        end

        @custom_body_class = "static-account-created"
        @message = session['user_created_message'] || I18n.t('activation.missing_session')
        @account_created = { message: @message, show_controls: false }

        if session_user_id = session[SessionController::ACTIVATE_USER_KEY]
          if user = User.where(id: session_user_id.to_i).first
            # custom logic >>>>
            @account_created[:name] = user.name
            @account_created[:billing_address] = user.billing_address
            # custom logic <<<<
            @account_created[:username] = user.username
            @account_created[:email] = user.email
            @account_created[:show_controls] = !user.from_staged?
            @account_created[:show_controls] = !user.from_staged?
          end
        end

        store_preloaded("accountCreated", MultiJson.dump(@account_created))
        expires_now

        respond_to do |format|
          format.html { render "default/empty" }
          format.json { render json: success_json }
        end
      end
    end

    ListController.class_eval do
      before_action :ensure_logged_in, except: [
        :topics_by,
        # anonymous filters
        Discourse.anonymous_filters,
        Discourse.anonymous_filters.map { |f| "#{f}_feed" },
        # anonymous categorized filters
        :category_default,
        Discourse.anonymous_filters.map { |f| :"category_#{f}" },
        Discourse.anonymous_filters.map { |f| :"category_none_#{f}" },
        # category feeds
        :category_feed,
        # user topics feed
        :user_topics_feed,
        # top summaries
        :top,
        :category_top,
        :category_none_top,
        # top pages (ie. with a period)
        TopTopic.periods.map { |p| :"top_#{p}" },
        TopTopic.periods.map { |p| :"top_#{p}_feed" },
        TopTopic.periods.map { |p| :"category_top_#{p}" },
        TopTopic.periods.map { |p| :"category_none_top_#{p}" },
        :group_topics,
        :category_dialogs,
        :category_none_dialogs
      ].flatten

      before_action :set_category, only: [
        :category_default,
        # filtered topics lists
        Discourse.filters.map { |f| :"category_#{f}" },
        Discourse.filters.map { |f| :"category_none_#{f}" },
        # top summaries
        :category_top,
        :category_none_top,
        # top pages (ie. with a period)
        TopTopic.periods.map { |p| :"category_top_#{p}" },
        TopTopic.periods.map { |p| :"category_none_top_#{p}" },
        # category feeds
        :category_feed,
        :category_dialogs,
        :category_none_dialogs
      ].flatten

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

        list.dialogs = @category ? dialogs(category: @category.id, without_respond: true).topics.first(5) : []

        respond_with_list(list)
      end

      def dialogs(options = nil)
        without_respond = options ? options.delete(:without_respond) : false

        filter = :dialogs
        list_opts = build_topic_list_options
        list_opts.merge!(options) if options
        user = list_target_user
        list_opts[:no_definitions] = true if params[:category].blank? && filter == :latest

        list = TopicQuery.new(user, list_opts).list_dialogs

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

        respond_with_list(list)
      end

      def category_dialogs
        canonical_url "#{Discourse.base_url_no_prefix}#{@category.url}"
        dialogs(category: @category.id)
      end

      def category_none_dialogs
        dialogs(category: @category.id, no_subcategories: true)
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
