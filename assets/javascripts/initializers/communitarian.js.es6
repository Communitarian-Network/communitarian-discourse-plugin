import { withPluginApi } from "discourse/lib/plugin-api";
import TopicController from "discourse/controllers/topic";
import ResolutionController from "../controllers/resolution-controller";
import discourseComputed from "discourse-common/utils/decorators";

const isHomePageField = {
  isHomePage: window.location.pathname === "/",
};

function initializeCommunitarian(api) {
  console.log("Communitarian plugin initialized");

  api.modifyClass("controller:discovery/categories", {
    isHomePage: isHomePageField.isHomePage,

    @discourseComputed(
      "model.categories",
      "siteSettings.landing_categories_length"
    )
    limitedCategories(categories, length) {
      this.set(
        "model.categories.content",
        categories.content.slice(0, length || 4)
      );
      return categories;
    },
  });

  api.modifyClass("controller:navigation/categories", isHomePageField);
}

function customizeTopicController() {
  TopicController.reopen(ResolutionController);
}

export default {
  name: "communitarian",

  initialize() {
    withPluginApi("0.8.31", initializeCommunitarian);
    withPluginApi("0.8.31", customizeTopicController);
  },
};
