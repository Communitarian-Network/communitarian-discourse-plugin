import DiscoveryTopicsListComponent from "discourse/components/discovery-topics-list";
import showModal from "discourse/lib/show-modal";

export default DiscoveryTopicsListComponent.extend({
  classNames: ["resolutions-list"],
  eyelineSelector: ".resolution-list-item",

  actions: {
    clickNewResolutionButton() {
      showModal("resolution-ui-builder")._setupPoll();
    }
  },
});
