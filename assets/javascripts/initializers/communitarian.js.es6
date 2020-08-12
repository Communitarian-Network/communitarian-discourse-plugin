import { withPluginApi } from "discourse/lib/plugin-api";
import TopicController from "discourse/controllers/topic";
import ResolutionController from "../controllers/resolution-controller";

function initializeCommunitarian(api) {
  console.log("Communitarian plugin initialized");
}

function customizeTopicController(api) {
  TopicController.reopen(ResolutionController);
}

export default {
  name: "communitarian",

  initialize() {
    withPluginApi("0.8.31", initializeCommunitarian);
    withPluginApi("0.8.31", customizeTopicController);
  }
};
