import Component from "@ember/component";
import showModal from "discourse/lib/show-modal";

export default Component.extend({
  actions: {
    clickCreateCommunityButton() {
      showModal("community-ui-builder");
    }
  }
});
