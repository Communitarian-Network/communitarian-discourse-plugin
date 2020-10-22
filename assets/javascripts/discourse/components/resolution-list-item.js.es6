import Component from "@ember/component";

import getResolutionPeriod from "./get-resolution-period";

export default Component.extend({
  init() {
    this._super(...arguments);
    this._setupPoll();
    if(this.recentResolution) {
      $(document).on(`post-${this.recentResolution.id}-poll-voted`, this._pollVoted.bind(this));
    }
  },

  willDestroyElement() {
    if(this.recentResolution) {
      $(document).off(`post-${this.recentResolution.id}-poll-voted`);
    }
    this._super(...arguments);
  },

  _pollVoted(_event, poll) {
    this.setProperties({ openedPoll: poll });
  },

  _setupPoll() {
    const recentResolution = this.resolution.recent_resolution_post;
    if (!recentResolution || !recentResolution.polls) {
      return;
    }

    const openedPoll = recentResolution.polls[0];

    const [created, closed] = [
      moment(this.resolution.created_at),
      moment(openedPoll.close),
    ];

    this.setProperties({
      recentResolution,
      openedPoll,
      formattedActionPeriod: getResolutionPeriod(created, closed)
    });
  },
});
