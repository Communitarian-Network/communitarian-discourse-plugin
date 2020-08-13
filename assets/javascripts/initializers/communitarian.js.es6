import I18n from "I18n";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setDefaultHomepage } from "discourse/lib/utilities";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";

function initializeCommunitarian(api) {
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

export default {
  name: "communitarian",

  initialize(container) {
    withPluginApi("0.8.31", initializeCommunitarian);
    const currentUser = container.lookup("current-user:main");
    if (!currentUser || !currentUser.homepage_id) setDefaultHomepage("home");
  },
};
