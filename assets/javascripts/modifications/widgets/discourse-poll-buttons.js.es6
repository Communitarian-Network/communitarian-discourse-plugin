import RawHtml from "discourse/widgets/raw-html";
import { relativeAge } from "discourse/lib/formatter";

export default {
  html(attrs) {
    const contents = [];
    const { poll, post } = attrs;
    const topicArchived = post.get("topic.archived");
    const closed = attrs.isClosed;
    const staffOnly = poll.results === "staff_only";
    const isStaff = this.currentUser && this.currentUser.staff;
    const isAdmin = this.currentUser && this.currentUser.admin;
    const isMe = this.currentUser && post.user_id === this.currentUser.id;
    const dataExplorerEnabled = this.siteSettings.data_explorer_enabled;
    const hideResultsDisabled = !staffOnly && (closed || topicArchived);
    const exportQueryID = this.siteSettings.poll_export_data_explorer_query_id;

    if (attrs.isMultiple && !hideResultsDisabled) {
      const castVotesDisabled = !attrs.canCastVotes;
      contents.push(
        this.attach("button", {
          className: `cast-votes ${
            castVotesDisabled ? "btn-default" : "btn-primary"
          }`,
          label: "poll.cast-votes.label",
          title: "poll.cast-votes.title",
          disabled: castVotesDisabled,
          action: "castVotes"
        })
      );
      contents.push(" ");
    }

    if (attrs.showResults || hideResultsDisabled) {
      contents.push(
        this.attach("button", {
          className: "btn-default toggle-results",
          label: "poll.hide-results.label",
          title: "poll.hide-results.title",
          icon: "far-eye-slash",
          disabled: hideResultsDisabled,
          action: "toggleResults"
        })
      );
    } else {
      if (poll.get("results") === "on_vote" && !attrs.hasVoted && !isMe) {
        contents.push(infoTextHtml(I18n.t("poll.results.vote.title")));
      } else if (poll.get("results") === "on_close" && !closed) {
        contents.push(infoTextHtml(I18n.t("poll.results.closed.title")));
      } else if (poll.results === "staff_only" && !isStaff) {
        contents.push(infoTextHtml(I18n.t("poll.results.staff.title")));
      } else {
        contents.push(
          this.attach("button", {
            className: "btn-default toggle-results",
            label: "poll.show-results.label",
            title: "poll.show-results.title",
            icon: "far-eye",
            disabled: poll.get("voters") === 0,
            action: "toggleResults"
          })
        );
      }
    }

    if (isAdmin && dataExplorerEnabled && poll.voters > 0 && exportQueryID) {
      contents.push(
        this.attach("button", {
          className: "btn btn-default export-results",
          label: "poll.export-results.label",
          title: "poll.export-results.title",
          icon: "download",
          disabled: poll.voters === 0,
          action: "exportResults"
        })
      );
    }

    // vvv custom behavior vvv
    if (poll.get("close") && poll.get("status") !== "closed") {
    // ^^^ custom behavior ^^^
      const closeDate = moment(poll.get("close"));
      if (closeDate.isValid()) {
        const title = closeDate.format("LLL");
        let label;

        if (attrs.isAutomaticallyClosed) {
          const age = relativeAge(closeDate.toDate(), { addAgo: true });
          label = I18n.t("poll.automatic_close.age", { age });
        } else {
          const timeLeft = moment().to(closeDate, true);
          label = I18n.t("poll.automatic_close.closes_in", { timeLeft });
        }

        contents.push(
          new RawHtml({
            html: `<span class="info-text" title="${title}">${label}</span>`
          })
        );
      }
    }

    if (
      this.currentUser &&
      (this.currentUser.get("id") === post.get("user_id") || isStaff) &&
      !topicArchived
    ) {
      if (closed) {
        if (!attrs.isAutomaticallyClosed) {
          contents.push(
            this.attach("button", {
              className: "btn-default toggle-status",
              label: "poll.open.label",
              title: "poll.open.title",
              icon: "unlock-alt",
              action: "toggleStatus"
            })
          );
        }
      } else {
        contents.push(
          this.attach("button", {
            className: "toggle-status btn-danger",
            label: "poll.close.label",
            title: "poll.close.title",
            icon: "lock",
            action: "toggleStatus"
          })
        );
      }
    }

    return contents;
  }
};
