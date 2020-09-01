import Component from "@ember/component";

export default Component.extend({
  classNames: ["dialog-list-item"],

  init() {
    this._super(...arguments);
    this._setupPoll();
  },

  _setupPoll() {
    const formattedCreationDate = moment(this.dialog.created_at).format("MMM ‘DD");
    this.setProperties({ formattedCreationDate });
  },
});
