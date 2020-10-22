import { reopenWidget } from "discourse/widgets/widget";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default {
  name: "communitarian-can-cast-votes",

  initialize() {
    reopenWidget("discourse-poll", {
      // plugins/poll/assets/javascripts/widgets/discourse-poll.js.es6:1034
      castVotes() {
        if (!this.canCastVotes()) return;
        if (!this.currentUser) return this.showLogin();

        const { attrs, state } = this;

        state.loading = true;

        return ajax("/polls/vote", {
          type: "PUT",
          data: {
            post_id: attrs.post.id,
            poll_name: attrs.poll.get("name"),
            options: attrs.vote
          }
        })
          .then(({ poll }) => {
            attrs.poll.setProperties(poll);
            if (attrs.poll.get("results") !== "on_close") {
              state.showResults = true;
            }
            if (attrs.poll.results === "staff_only") {
              if (this.currentUser && this.currentUser.get("staff")) {
                state.showResults = true;
              } else {
                state.showResults = false;
              }
            }
            // vvv custom behavior vvv
            $(document).trigger(`post-${attrs.post.id}-poll-voted`, poll);
          })
          .catch(error => {
            if (error) {
              popupAjaxError(error);
            } else {
              bootbox.alert(I18n.t("poll.error_while_casting_votes"));
            }
          })
          .finally(() => {
            state.loading = false;
          });
      },

      // plugins/poll/assets/javascripts/widgets/discourse-poll.js.es6:892
      canCastVotes() {
        const { state, attrs } = this;

        if (this.isClosed() || state.showResults || state.loading) {
          return false;
        }

        let selectedOptionCount = attrs.vote.length;

        // vvv custom behavior vvv
        let selection = attrs.poll.options.map(option => ({
          html: option.html,
          selected: (attrs.vote.indexOf(option.id) !== -1)
        }));

        const closeText = I18n.t("communitarian.resolution.ui_builder.poll_options.close_option");

        let closeOption = selection.find(option => option.html === closeText);
        let isResolution = this.isMultiple() && closeOption && this.min() === 1 && this.max() === 2;

        if (isResolution) {
          return selectedOptionCount === 2 && closeOption.selected || selectedOptionCount === 1;
          // ^^^ custom behavior ^^^
        } else if (this.isMultiple()) {
          return (
            selectedOptionCount >= this.min() && selectedOptionCount <= this.max()
          );
        }

        return selectedOptionCount > 0;
      },
    });
  },
};
