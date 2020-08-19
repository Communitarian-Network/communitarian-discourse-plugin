import Component from "@ember/component";

export default Component.extend({
  init() {
    this._super(...arguments);
    this._setupPoll();
  },

  _setupPoll() {
    window.e = this;
    const openedPoll = this.resolution.recent_resolution_post.polls[0];
    const creationMonth = moment(this.resolution.created_at).format("MMM");
    const creationDate = moment(this.resolution.created_at).format("DD");
    const closeMonth = moment(openedPoll.close).format("MMM");
    const closeDate = moment(openedPoll.close).format("DD");
    let actionPeriod = [creationMonth, creationDate, "-"];
    if (creationMonth != closeMonth) {
      actionPeriod.push(closeMonth);
    };
    actionPeriod.push(closeDate);
    this.setProperties({
      openedPoll: openedPoll,
      formattedActionPeriod: actionPeriod.join(" ")
    });
  }
});
