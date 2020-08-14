import showModal from "discourse/lib/show-modal";
import Component from "@ember/component";

export default Component.extend({
  actions: {
    clickCreateResolutionButton() {
      showModal("resolution-ui-builder")._setupPoll();
    }
}});
