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
gem "zip-codes", "0.2.0"

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

  add_to_serializer(:basic_category, :introduction_raw) do
    object.uncategorized? ? I18n.t('category.uncategorized_description') : object.custom_fields["introduction_raw"]
  end

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

      def zipcode
        UserCustomField.find_by(user_id: id, name: :user_field_123002)&.value
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

      def create
        params.require(:email)
        params.require(:username)
        params.require(:invite_code) if SiteSetting.require_invite_code
        params.permit(:user_fields)

        unless SiteSetting.allow_new_registrations
          return fail_with("login.new_registrations_disabled")
        end

        if params[:password] && params[:password].length > User.max_password_length
          return fail_with("login.password_too_long")
        end

        if params[:email].length > 254 + 1 + 253
          return fail_with("login.email_too_long")
        end

        if SiteSetting.require_invite_code && SiteSetting.invite_code.strip.downcase != params[:invite_code].strip.downcase
          return fail_with("login.wrong_invite_code")
        end

        if clashing_with_existing_route?(params[:username]) || User.reserved_username?(params[:username])
          return fail_with("login.reserved_username")
        end

        params[:locale] ||= I18n.locale unless current_user

        new_user_params = user_params.except(:timezone)

        user = User.where(staged: true).with_email(new_user_params[:email].strip.downcase).first

        if user
          user.active = false
          user.unstage!
        end

        user ||= User.new
        user.attributes = new_user_params

        # Handle API approval and
        # auto approve users based on auto_approve_email_domains setting
        if user.approved? || EmailValidator.can_auto_approve_user?(user.email)
          ReviewableUser.set_approved_fields!(user, current_user)
        end

        # Handle custom fields
        user_fields = UserField.all
        if user_fields.present?
          field_params = user_fields_params
          fields = user.custom_fields

          user_fields.each do |f|
            field_val = field_params[f.id.to_s]
            if field_val.blank?
              return fail_with("login.missing_user_field") if f.required?
            else
              fields["#{User::USER_FIELD_PREFIX}#{f.id}"] = field_val[0...UserField.max_length]
            end
          end

          user.custom_fields = fields
        end

        authentication = UserAuthenticator.new(user, session)

        if !authentication.has_authenticator? && !SiteSetting.enable_local_logins && !(current_user&.admin? && is_api?)
          return render body: nil, status: :forbidden
        end

        authentication.start

        if authentication.email_valid? && !authentication.authenticated?
          # posted email is different that the already validated one?
          return fail_with('login.incorrect_username_email_or_password')
        end

        activation = UserActivator.new(user, request, session, cookies)
        activation.start

        # just assign a password if we have an authenticator and no password
        # this is the case for Twitter
        user.password = SecureRandom.hex if user.password.blank? && authentication.has_authenticator?

        if user.save
          authentication.finish
          activation.finish
          user.update_timezone_if_missing(params[:timezone])

          secure_session[HONEYPOT_KEY] = nil
          secure_session[CHALLENGE_KEY] = nil

          # save user email in session, to show on account-created page
          session["user_created_message"] = activation.message
          session[SessionController::ACTIVATE_USER_KEY] = user.id

          # If the user was created as active this will
          # ensure their email is confirmed and
          # add them to the review queue if they need to be approved
          user.activate if user.active?

          render json: {
            success: true,
            active: user.active?,
            message: activation.message,
            user_id: user.id
          }
        elsif SiteSetting.hide_email_address_taken && user.errors[:primary_email]&.include?(I18n.t('errors.messages.taken'))
          session["user_created_message"] = activation.success_message

          if existing_user = User.find_by_email(user.primary_email&.email)
            Jobs.enqueue(:critical_user_email, type: :account_exists, user_id: existing_user.id)
          end

          render json: {
            success: true,
            active: user.active?,
            message: activation.success_message,
            user_id: user.id
          }
        else
          errors = user.errors.to_hash
          errors[:email] = errors.delete(:primary_email) if errors[:primary_email]

          render json: {
            success: false,
            message: I18n.t(
              'login.errors',
              errors: user.errors.full_messages.join("\n")
            ),
            errors: errors,
            values: {
              name: user.name,
              username: user.username,
              email: user.primary_email&.email
            },
            is_developer: UsernameCheckerService.is_developer?(user.email)
          }
        end
      rescue ActiveRecord::StatementInvalid
        render json: {
          success: false,
          message: I18n.t("login.something_already_taken")
        }
      end

      HONEYPOT_KEY ||= 'HONEYPOT_KEY'
      CHALLENGE_KEY ||= 'CHALLENGE_KEY'

      protected

      def honeypot_value
        secure_session[HONEYPOT_KEY] ||= SecureRandom.hex
      end

      def challenge_value
        secure_session[CHALLENGE_KEY] ||= SecureRandom.hex
      end

      private

      def user_fields_params
        fields_params = params[:user_fields] || {}

        return unless fields_params["123001"] == "unknown" || fields_params["123001"].blank?

        address = zipcode_address(fields_params["123002"]) || "unknown"
        fields_params.merge("123001" => address)
      end

      def zipcode_address(zipcode = nil)
        ZipCodes.identify(zipcode).to_h.slice(:state_name, :city).values.reject(&:blank?).join(", ").presence
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
