import I18n from "I18n";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setDefaultHomepage } from "discourse/lib/utilities";
import TopicController from "discourse/controllers/topic";
import ResolutionController from "../controllers/resolution-controller";
import discourseComputed from "discourse-common/utils/decorators";
import { registerUnbound } from "discourse-common/lib/helpers";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";

function initializeCommunitarian(api) {
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


  registerUnbound('compare', function(v1, operator, v2) {
    let operators = {
      '===': (l, r) => l === r,
      '!=': (l, r) => l != r,
      '>':  (l, r) => l >  r,
      '>=': (l, r) => l >= r,
      '<':  (l, r) => l <  r,
      '<=': (l, r) => l <= r,
    };
    return operators[operator] && operators[operator](v1, v2);
  });

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


  api.modifyClass("controller:create-account", {
    performAccountCreation() {
      const data = {
        name: this.accountName,
        email: this.accountEmail,
        password: this.accountPassword,
        username: this.accountUsername,
        password_confirmation: this.accountHoneypot,
        challenge: this.accountChallenge,
        user_fields: this.userFields,
      };

      this.set("formSubmitted", true);
      _createAccount(data, this);
    },
  });
}

function _createAccount(data, self) {
  return ajax("/communitarian/users/new", { type: "GET", data: data })
    .then(() => {
      _createVerificationIntent(data, self);
    })
    .catch((error) => {
      self.set("formSubmitted", false);
      if (error) {
        self.flash(extractError(error), "error");
      } else {
        bootbox.alert(
          I18n.t("communitarian.verification.error_while_creating")
        );
      }
    });
}

function _createVerificationIntent(data, self) {
  return ajax("/communitarian/verification_intents", {
    type: "POST",
    data: data,
  })
    .then((response) => {
      window.location = response.verification_intent.verification_url;
    })
    .catch((error) => {
      self.set("formSubmitted", false);
      if (error) {
        self.flash(extractError(error), "error");
      } else {
        bootbox.alert(
          I18n.t("communitarian.verification.error_while_creating")
        );
      }
    });
}

function customizeTopicController() {
  TopicController.reopen(ResolutionController);
}

export default {
  name: "communitarian",

  initialize(container) {
    withPluginApi("0.8.31", initializeCommunitarian);
    const currentUser = container.lookup("current-user:main");
    if (!currentUser || !currentUser.homepage_id) setDefaultHomepage("home");
    withPluginApi("0.8.31", customizeTopicController);
  },
};
