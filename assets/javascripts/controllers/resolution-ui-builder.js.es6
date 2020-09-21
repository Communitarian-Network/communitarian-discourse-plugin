import I18n from "I18n";
import Controller from "@ember/controller";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { throttle } from "@ember/runloop";

export default Controller.extend({
  weekdays: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],

  init() {
    this._super(...arguments);
    this._setupPoll();
  },

  @discourseComputed("pollOptions")
  pollOptionsCount(pollOptions) {
    const notEmpty = Boolean;
    return pollOptions.split("\n").filter(notEmpty).length;
  },

  @discourseComputed("pollOutput", "title")
  previewText(pollOptions, title) {
    let output = "";

    if (title.length > 0) output += `${title}\n`;

    output += this.pollOutput;

    return output;
  },

  @discourseComputed("pollOptions")
  pollOutput(pollOptions) {
    let closeDateString = this._closeDate().toISOString();
    let pollHeader = `[poll type=multiple results=always min=1 max=2 chartType=bar close=${closeDateString}]`;

    let output = "";
    output += `${pollHeader}\n`;
    output += this._parsedPollOptions(pollOptions);
    output += "[/poll]\n";

    return output;
  },

  @discourseComputed("pollOptionsCount")
  minNumOfOptionsValidation(count) {
    let options = { ok: true };

    if (count < 1) {
      options = {
        failed: true,
        reason: I18n.t("communitarian.resolution.ui_builder.help.options_count")
      };
    }

    return EmberObject.create(options);
  },

  @discourseComputed("title")
  titleMaxLengthValidation(title) {
    let options = { ok: true };

    if (title.length > this.siteSettings.max_topic_title_length) {
      options = {
        failed: true,
        reason: I18n.t("composer.error.title_too_long", { max: this.siteSettings.max_topic_title_length })
      };
    }

    return EmberObject.create(options);
  },

  @discourseComputed("pollOptionsCount", "title", "loading")
  disabledButton(pollOptionsCount, title, loading) {
    return (
      loading ||
      pollOptionsCount < 1 ||
      title.length > this.siteSettings.max_topic_title_length
    );
  },

  @observes("title", "pollOptions")
  typing() {
    throttle(
      this,
      function() {
        const typingTime = this.typingTime || 0;
        this.set("typingTime", typingTime + 100);
      },
      100,
      false
    );
  },

  _setupPoll(postId = null) {
    if (postId === null) {
      let slug = window.location.pathname.match(/c\/.*\/(.*)$/);
      this.setProperties({
        action: "create",
        buttonLabel: "communitarian.resolution.ui_builder.create",
        formTitle: "communitarian.resolution.ui_builder.form_title.new",
        postId: null,
        title: "",
        pollOptions: "",
        titleMaxLength: this.siteSettings.max_topic_title_length,
        loading: false,
        typingTime: 0,
        firstOpenedTimestamp: new Date(),
        category: slug && slug[1],
        autoCloseReminder: this._autoCloseReminderText(),
        activePeriodNote: I18n.t("communitarian.resolution.ui_builder.active_period_note"),
      });
    } else {
      this.setProperties({
        action: "update",
        buttonLabel: "communitarian.resolution.ui_builder.update",
        formTitle: "communitarian.resolution.ui_builder.form_title.edit",
      });
      this.store.find("post", postId).then((post) => {
        this.setProperties({
          postId: post.id,
          pollOptions: this._parseOptionsFromRaw(post.raw),
          category: post.topic.category_id,
          title: post.topic.title,
        });
      });
    }
  },

  _parseOptionsFromRaw(postRaw) {
    const options = postRaw.match(/\[.+\]\n((\*\s.+\n)+)\[.+\]/)[1].split("\n");
    return options
      .filter(s => s !== "")
      .map(s => s.substring(2))
      .filter(s => s !== I18n.t("communitarian.resolution.ui_builder.poll_options.close_option"))
      .join("\n");
  },

  _autoCloseReminderText() {
    const closeDate = this._closeDate().format("MMMM D, ha");
    const reopenDelay = this.siteSettings.communitarian_resolutions_reopen_delay;
    if (reopenDelay === 0) {
      return I18n.t(
        "communitarian.resolution.ui_builder.auto_close_and_reopen_reminder",
        { close_date: closeDate }
      );
    } else {
      return I18n.t(
        "communitarian.resolution.ui_builder.auto_close_and_reopen_with_delay_reminder",
        { close_date: closeDate, delay: reopenDelay }
      );
    }
  },

  _closeDate() {
    const closeHour = this.siteSettings.communitarian_resolutions_close_hour;
    const closeWeekDay = this.siteSettings.communitarian_resolutions_close_week_day;
    const closeDate = moment
      .tz("America/New_York")
      .set({ hours: closeHour, minutes: 0, seconds: 0, millisecond: 0 });
    const currentWeekday = this.weekdays[closeDate.weekday()];
    const closeOnNextWeek = () => this.weekdays.indexOf(currentWeekday) >= this.weekdays.indexOf(closeWeekDay);

    // choose next week if current weekday already passed close weekday
    if (closeOnNextWeek()) closeDate.add(1, "week");

    closeDate.isoWeekday(closeWeekDay);

    return closeDate;
  },

  _parsedPollOptions(pollOptions) {
    let output = "";

    if (pollOptions.length > 0) {
      pollOptions.split("\n").forEach(option => {
        if (option.length !== 0) output += `* ${option}\n`;
      });
      if (this.siteSettings.communitarian_resolutions_close) {
        output += `* ${I18n.t("communitarian.resolution.ui_builder.poll_options.close_option")}\n`;
      }
    }

    return output;
  },

  createResolution(totalOpenDuration) {
    return ajax("/communitarian/resolutions", {
      type: "POST",
      data: {
        title: this.title,
        raw: this.pollOutput,
        category: this.category,
        typing_duration_msecs: this.typingTime,
        composer_open_duration_msecs: totalOpenDuration
      }
    }).then(response => {
      window.location = `/t/topic/${response.post.topic_id}`;
    }).catch(error => {
      this.set("loading", false);
      if (error) {
        popupAjaxError(error);
      } else {
        bootbox.alert(I18n.t("communitarian.resolution.error_while_creating"));
      }
    });
  },

  updateResolution(totalOpenDuration) {
    return ajax(`/posts/${this.postId}`, {
      type: "PATCH",
      data: {
        title: this.title,
        post: { raw: this.pollOutput },
        typing_duration_msecs: this.typingTime,
        composer_open_duration_msecs: totalOpenDuration
      }
    }).then(() => {
      this._setupPoll();
      $(".modal-header button.modal-close").click();
      this.set("loading", false);
    }).catch(error => {
      this.set("loading", false);
      if (error) {
        popupAjaxError(error);
      } else {
        bootbox.alert(I18n.t("communitarian.resolution.error_while_updating"));
      }
    });
  },

  actions: {
    submitResolution() {
      if (this.disabledButton || this.loading) {
        return;
      }

      const totalOpenDuration = new Date() - this.firstOpenedTimestamp;

      this.set("loading", true);

      if (this.action === "create") {
        return this.createResolution(totalOpenDuration);
      } else if (this.action === "update") {
        return this.updateResolution(totalOpenDuration);
      }
    },
  }
});
