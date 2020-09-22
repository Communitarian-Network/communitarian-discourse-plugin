import DiscoveryTopicsListComponent from "discourse/components/discovery-topics-list";
import showModal from "discourse/lib/show-modal";

export default DiscoveryTopicsListComponent.extend({
  classNames: ["resolutions-list"],
  eyelineSelector: ".resolution-list-item",

  actions: {
    clickNewResolutionButton() {
      if (this.currentUser) {
        showModal("resolution-ui-builder")._setupPoll();
      } else {
        this.store.register.lookup("route:application").send("showLogin");
      }
    },
  },
});
