import { withPluginApi } from "discourse/lib/plugin-api";
import discourseComputed from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";

const isHomePageField = {
  isHomePage: window.location.pathname === "/",
};

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

  api.modifyClass("controller:navigation/categories", isHomePageField);
  api.modifyClass("controller:create-account", {
    performAccountCreation() {
      const data = {
        name: this.accountName,
        email: this.accountEmail,
        password: this.accountPassword,
        username: this.accountUsername,
        password_confirmation: this.accountHoneypot,
        challenge: this.accountChallenge,
        user_fields: this.userFields
      };

      this.set("formSubmitted", true);
      _createAccount(data, this);
    }
  });
}

function _createAccount(data, self) {
  return ajax("/communitarian/users/new", { type: "GET", data: data})
    .then(response => {
      _createVerificationIntent(data, self);
    })
    .catch(error => {
      self.set("formSubmitted", false);
      if (error) {
        self.flash(extractError(error), "error");
      } else {
        bootbox.alert(I18n.t("communitarian.verification.error_while_creating"));
      }
    });
}

function _createVerificationIntent(data, self) {
  return ajax("/communitarian/verification_intents", { type: "POST", data: data })
    .then(response => {
      window.location = response.verification_intent.verification_url;
    })
    .catch(error => {
      self.set("formSubmitted", false);
      if (error) {
        self.flash(extractError(error), "error");
      } else {
        bootbox.alert(I18n.t("communitarian.verification.error_while_creating"));
      }
    });
}

export default {
  name: "communitarian",

  initialize() {
    withPluginApi("0.8.31", initializeCommunitarian);
  },
};
