import { withPluginApi } from "discourse/lib/plugin-api";
import discourseComputed from "discourse-common/utils/decorators";
import { registerUnbound } from "discourse-common/lib/helpers";

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

  registerUnbound('compare', function(v1, operator, v2) {
    let operators = {
      '==': (l, r) => l == r,
      '!=': (l, r) => l != r,
      '>':  (l, r) => l >  r,
      '>=': (l, r) => l >= r,
      '<':  (l, r) => l <  r,
      '<=': (l, r) => l <= r,
    };
    return operators[operator] && operators[operator](v1, v2);
  });
}

export default {
  name: "communitarian",

  initialize() {
    withPluginApi("0.8.31", initializeCommunitarian);
  },
};
