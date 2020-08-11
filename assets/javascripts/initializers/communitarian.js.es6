import { withPluginApi } from "discourse/lib/plugin-api";
import { setDefaultHomepage } from "discourse/lib/utilities";
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

export default {
  name: "communitarian",

  initialize(container) {
    withPluginApi("0.8.31", initializeCommunitarian);
    const currentUser = container.lookup('current-user:main');
    if (!currentUser || !currentUser.homepage_id) setDefaultHomepage('home');
  }
};
