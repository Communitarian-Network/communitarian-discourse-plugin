import { later } from "@ember/runloop";
import getURL from "discourse-common/lib/get-url";
import PreloadStore from "discourse/lib/preload-store";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseRoute from "discourse/routes/discourse";
import User from "discourse/models/user";

export default DiscourseRoute.extend({
  setupController(controller, model) {
    controller.setProperties({
      closeIconUrl: getURL("/plugins/communitarian/images/close-icon.svg"),
      checkIconUrl: getURL("/plugins/communitarian/images/check-icon.svg"),
      model,
    });
  },

  model(params) {
    const self = this;
    return this.store
      .find("verification-intent", params.id, { backgroundReload: true })
      .then((item) => {
        if (item.status == "succeeded") {
          later(() => {
            this._finishSignUp(item.full_name, item.billing_address, item.zipcode);
          }, 3000);
        }
        if (item.status == "processing") {
          later(() => {
            self.model({ id: params.id });
          }, 3000);
        }
        return item;
      });
  },

  renderTemplate() {
    this.render("verification-intents/show");
  },

  _finishSignUp(accountName, address, zipcode) {
    const signupData = PreloadStore.get("signupData");
    // We use address from First step form, not from Stripe Identity

    const attrs = {
      accountName,
      accountEmail: signupData.email,
      accountPassword: signupData.password,
      accountUsername: signupData.username,
      accountPasswordConfirm: signupData.password_confirmation,
      accountChallenge: signupData.challenge,
      userFields: { 123001: signupData.billing_address, 123002: zipcode }
    };

    return User.createAccount(attrs)
      .then((result) => {
        if (result.success) {
          later(() => window.location = "/u/account-created", 3000);
        } else {
          popupAjaxError(result);
        }
      })
      .catch((error) => {
        window.location.reload();
      });
  },

  actions: {
    error(error) {
      window.location = "/";
    },
  },
});
