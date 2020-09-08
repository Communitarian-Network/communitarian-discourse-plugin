import { reopenWidget } from "discourse/widgets/widget";

export default {
  name: "communitarian-can-cast-votes",

  initialize() {
    reopenWidget("discourse-poll", {
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
