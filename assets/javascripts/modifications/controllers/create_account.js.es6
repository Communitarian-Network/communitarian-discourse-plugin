import discourseComputed from "discourse-common/utils/decorators";
import showModal from "discourse/lib/show-modal";
import Site from "discourse/models/site";
import LoginMethod from "discourse/models/login-method";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";

export default {
  onShow() {
    this.setProperties({
      accountUsername: Date.now()
    });
  },

  @discourseComputed
  nextStepLabel() {
    if (this.get("authOptions.email")) {
      return "create_account.title";
    } else {
      return "communitarian.create_account.continue";
    }
  },

  @discourseComputed
  authButtons() {
    const methods = [];

    if (this.get("siteSettings.linkedin_enabled")) {
      const linkedinProvider = Site.currentProp("auth_providers").find(provider => provider.name === "linkedin");
      methods.pushObject(LoginMethod.create(linkedinProvider));
    };

    return methods;
  },

  performAccountCreation() {
    if (this.get("authOptions.email") === this.accountEmail) {
      return this._super(...arguments);
    }

    const data = {
      name: this.accountName,
      email: this.accountEmail,
      password: this.accountPassword,
      username: this.accountUsername,
      password_confirmation: this.accountHoneypot,
      challenge: this.accountChallenge,
    };

    this.set("formSubmitted", true);
    this._createAccount(data, this);
  },

  fieldsValid() {
    this.clearFlash();

    const validation = [
      this.emailValidation,
      this.nameValidation,
      this.passwordValidation
    ].find(v => v.failed);

    if (validation) {
      if (validation.message) {
        this.flash(validation.message, "error");
      }

      const element = validation.element;
      if (element.tagName === "DIV") {
        if (element.scrollIntoView) {
          element.scrollIntoView();
        }
        element.click();
      } else {
        element.focus();
      }

      return false;
    }
    return true;
  },

  actions: {
    showNextStep() {
      this.clearFlash();

      if (this.get("authOptions.email") == this.accountEmail) {
        return this.performAccountCreation();
      }

      if (this.fieldsValid()) {
        const {
          sign_up_with_credit_card_enabled: creditCardIdentity,
          sign_up_with_stripe_identity_enabled: stripeIdentity,
        } = this.siteSettings;

        if (creditCardIdentity && stripeIdentity) {
          showModal("choose-verification-way");
        } else if (creditCardIdentity) {
          showModal("payment-details");
        } else {
          if (new Date() - this._challengeDate > 1000 * this._challengeExpiry) {
            this.fetchConfirmationValue().then(() =>
              this.performAccountCreation()
            );
          } else {
            this.performAccountCreation();
          }
        }
      }
    },
  },

  _createAccount(data, self) {
    return ajax("/communitarian/users/new", { type: "GET", data: data })
      .then(() => {
        this._createVerificationIntent(data, self);
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
  },

  _createVerificationIntent(data, self) {
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
};
