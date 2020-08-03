import I18n from "I18n";
import Controller from "@ember/controller";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { throttle } from "@ember/runloop";

export default Controller.extend({
  init() {
    this._super(...arguments);
    this._setupPoll();
  },

  @discourseComputed("pollOptions")
  pollOptionsCount(pollOptions) {
    if (pollOptions.length === 0) return 0;

    let length = 0;

    pollOptions.split("\n").forEach(option => {
      if (option.length !== 0) length += 1;
    });

    return length;
  },

  @discourseComputed("pollOptions")
  pollOutput(pollOptions) {
    let pollHeader = "[poll type=regular results=always chartType=bar";
    let output = "";
    let closeDate = moment.tz("america_new_york").set({ hours: 17, minutes: 0, seconds: 0, millisecond: 0 });
    const currentWeekday = closeDate.weekday();
    const closeWeekDay = 6;

    // choose next saturday if current work week has been finished
    if (currentWeekday > 0 && currentWeekday < 6) {
      closeDate.isoWeekday(closeWeekDay);
    } else {
      closeDate.add(1, "week").isoWeekday(closeWeekDay);
    }

    pollHeader += ` close=${closeDate.toISOString()}`;

    pollHeader += "]";
    output += `${pollHeader}\n`;

    if (pollOptions.length > 0) {
      pollOptions.split("\n").forEach(option => {
        if (option.length !== 0) output += `* ${option}\n`;
      });
      output += `* ${I18n.t("communitarian.resolution.ui_builder.poll_options.close_option")}\n`
    }

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
    if (loading) {
      return true;
    } else {
      return (pollOptionsCount < 1 || title.length > this.siteSettings.max_topic_title_length);
    }
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

  _setupPoll() {
    this.setProperties({
      title: "",
      pollOptions: "",
      titleMaxLength: this.siteSettings.max_topic_title_length,
      loading: false,
      typingTime: 0,
      firstOpenedTimestamp: new Date(),
      category: window.location.pathname.match(/c\/.*\/(.*)$/)[1],
    });
  },

  actions: {
    createResolution() {
      if (this.disabledButton || this.loading) {
        return;
      }

      const totalOpenDuration = new Date() - this.firstOpenedTimestamp;

      this.set("loading", true);

      return ajax("/communitarian/resolutions", {
        type: "POST",
        data: {
          title: this.title,
          raw: this.pollOutput,
          category: this.category,
          typing_duration_msecs: this.typingTime,
          composer_open_duration_msecs: totalOpenDuration
        }
      })
        .then(response => {
          window.location = `/t/topic/${response.post.topic_id}`;
        })
        .catch(error => {
          this.set("loading", false);
          if (error) {
            popupAjaxError(error);
          } else {
            bootbox.alert(I18n.t("communitarian.resolution.error_while_creating"));
          }
        });
    }
  }
});
