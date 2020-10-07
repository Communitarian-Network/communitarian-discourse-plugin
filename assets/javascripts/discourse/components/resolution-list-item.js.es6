import Component from "@ember/component";

import getResolutionPeriod from "./get-resolution-period";

export default Component.extend({
  init() {
    this._super(...arguments);
    this._setupPoll();
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
      openedPoll,
      formattedActionPeriod: getResolutionPeriod(created, closed)
    });
  },
});
