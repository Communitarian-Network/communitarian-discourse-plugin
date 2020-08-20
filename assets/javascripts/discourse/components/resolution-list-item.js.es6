import Component from "@ember/component";

export default Component.extend({
  init() {
    this._super(...arguments);
    this._setupPoll();
  },

  _setupPoll() {
    window.e = this;

    const recentResolution = this.resolution.recent_resolution_post;
    if (!recentResolution) {
      return;
    }

    const openedPoll = recentResolution.polls[0];

    const [created, closed] = [
      moment(this.resolution.created_at),
      moment(openedPoll.close),
    ];

    const [
      creationMonth,
      creationDate,
      closeMonth,
      closeDate,
      actionPeriod,
    ] = [
      created.format("MMM"),
      created.date(),
      closed.format("MMM"),
      closed.date(),
      [creationMonth, creationDate, "-"],
    ];

    if (creationMonth !== closeMonth) {
      actionPeriod.push(closeMonth);
    }
    actionPeriod.push(closeDate);

    this.setProperties({
      openedPoll,
      formattedActionPeriod: actionPeriod.join(" "),
    });
  },
});
