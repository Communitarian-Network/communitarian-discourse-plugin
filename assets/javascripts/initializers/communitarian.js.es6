import { withPluginApi } from "discourse/lib/plugin-api";
import { setDefaultHomepage } from "discourse/lib/utilities";

function initializeCommunitarian(api) {
  console.log("Communitarian plugin initialized")
}

export default {
  name: "communitarian",

  initialize(container) {
    withPluginApi("0.8.31", initializeCommunitarian);
    const currentUser = container.lookup('current-user:main');
    if (!currentUser || !currentUser.homepage_id) setDefaultHomepage('home');
  }
};
