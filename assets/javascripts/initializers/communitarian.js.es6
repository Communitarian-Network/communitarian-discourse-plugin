import { withPluginApi } from "discourse/lib/plugin-api";

function initializeCommunitarian(api) {
  console.log("Communitarian plugin initialized")
}

export default {
  name: "communitarian",

  initialize() {
    withPluginApi("0.8.31", initializeCommunitarian);
  }
};
