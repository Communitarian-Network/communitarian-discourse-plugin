import discourseComputed from "discourse-common/utils/decorators";
import showModal from "discourse/lib/show-modal";
import Site from "discourse/models/site";
import LoginMethod from "discourse/models/login-method";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";

export default {
  onShow() {
    this.setProperties({
      accountUsername: Date.now(),
      country: "",
      state: "",
      city: "",
      billingAddress: ""
    });
  },

  @discourseComputed("formSubmitted", "country", "city")
  submitDisabled(formSubmitted, country, city) {
    return (
      this.formSubmitted ||
      !country.replace(/\s/g, "").length ||
      !city.replace(/\s/g, "").length
    );
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

    this.set("formSubmitted", true);
    this._validateUserFields(this._createVerificationIntent.bind(this));
  },

  formValid(successCallback) {
    return this.fieldsValid() && this._validateUserFields(successCallback);
  },

  setBillingAddress() {
    this.set("billingAddress", this.parsedAddress());
  },

  parsedAddress() {
    if (this.state.replace(/\s/g, "").length === 0) {
      return (this.country + ", " + this.city);
    } else {
      return (this.country + ", " + this.state + ", " + this.city);
    }
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
    submitForm() {
      this.clearFlash();
      this.setBillingAddress();

      if (this.get("authOptions.email") == this.accountEmail) {
        return this.performAccountCreation();
      }

      this.formValid(this.switchToNextStep.bind(this));
    },
  },

  switchToNextStep() {
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
          this._createVerificationIntent()
        );
      } else {
        this._createVerificationIntent();
      }
    }
  },

  _validateUserFields(successCallback) {
    return ajax("/communitarian/users/new", { type: "GET", data: this._userFields() })
      .then(() => {
        successCallback();
      })
      .catch((error) => {
        this.set("formSubmitted", false);
        if (error) {
          this.flash(extractError(error), "error");
        } else {
          bootbox.alert(
            I18n.t("communitarian.verification.error_while_creating")
          );
        }
        return false;
    });
  },

  _createVerificationIntent() {
    return ajax("/communitarian/verification_intents", {
      type: "POST",
      data: this._userFields(),
    })
      .then((response) => {
        window.location = response.verification_intent.verification_url;
      })
      .catch((error) => {
        this.set("formSubmitted", false);
        if (error) {
          this.flash(extractError(error), "error");
        } else {
          bootbox.alert(
            I18n.t("communitarian.verification.error_while_creating")
          );
        }
      });
  },

  _userFields() {
    const data = {
      name: this.accountName,
      email: this.accountEmail,
      password: this.accountPassword,
      username: this.accountUsername,
      password_confirmation: this.accountHoneypot,
      challenge: this.accountChallenge,
      billing_address: this.billingAddress
    };

    return data;
  }
};
