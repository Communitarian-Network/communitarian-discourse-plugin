import Component from "@ember/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default Component.extend({
  classNames: ["dialog-list"],
  router: service(),

  @action
  goToDialogsPage() {
    DiscourseURL.routeTo(`${window.location.pathname}/l/dialogs`);
  },
});
