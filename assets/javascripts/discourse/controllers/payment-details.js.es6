import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import User from "discourse/models/user";

export default Controller.extend({
  createAccount: Ember.inject.controller(),

  @discourseComputed("name", "clientSecret", "loading", "zipcode")
  submitDisabled(name, clientSecret, loading, zipcode) {
    return (
      loading ||
      !clientSecret.length ||
      !name.replace(/\s/g, "").length ||
      !zipcode.replace(/\s/g, "").length
    );
  },

  onShow() {
    this.setProperties({
      loading: false,
      clientSecret: "",
      errorMessage: "",
      name: "",
      zipcode: ""
    });
    this._createPaymentIntent();
  },

  actions: {
    submitPaymentDetails(event) {
      if (event) event.preventDefault();
      if (this.submitDisabled) return;
      this.set("loading", true);
      this.set("errorMessage", "");
      if (this.paymentConfirmed) {
        this._createAccount();
      } else {
        this._confirmCardPayment();
      }
    },
  },
  _confirmCardPayment() {
    self = this;
    window.stripe.confirmCardPayment(
      this.clientSecret, {
      payment_method: {
        card: window.card,
        billing_details: {
          name: self.name,
          email: this.createAccount.accountEmail
        }
      }
    })
    .then(function(result) {
      if (result.error) {
        self._showError(result.error.message);
      } else {
        self.set("paymentConfirmed", true);
        self._createAccount()
      }
    });
  },
  _createAccount() {
    const userfields = { 123002: this.zipcode };
    let attrs = {
      accountName: this.name,
      accountEmail: this.createAccount.accountEmail,
      accountPassword: this.createAccount.accountPassword,
      accountUsername: this.createAccount.accountUsername,
      accountPasswordConfirm: this.createAccount.accountHoneypot,
      accountChallenge: this.createAccount.accountChallenge,
      userFields: userfields
    };

    return User.createAccount(attrs)
      .then((result) => {
        if (result.success) {
          window.location = "/u/account-created";
        } else {
          this.set("loading", false)
          popupAjaxError({ responseJSON: result });
        }
      })
      .catch((error) => {
        this.set("loading", false)
        popupAjaxError(error);
      });;
  },
  _showError(errorMsgText) {
    this.set("loading", false)
    this.set("errorMessage", errorMsgText);
  },
  _createPaymentIntent() {
    ajax("/communitarian/payment_intents", {
      method: "POST",
      data: {
        email: this.createAccount.accountEmail
      }
    })
      .then((data) => {
        this.set("clientSecret", data.payment_intent.client_secret);
      })
      .catch((error) => {
        this.set("loading", false);
        if (error) {
          popupAjaxError(error);
        }
      });
  }
});
