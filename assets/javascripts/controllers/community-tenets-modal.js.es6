import Controller from "@ember/controller";

export default Controller.extend({
  init() {
    this._super(...arguments);
  },

  setTenets(communityTenets) {
    this.setProperties({ communityTenets });
  },
});
