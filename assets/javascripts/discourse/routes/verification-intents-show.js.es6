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
            this._finishSignUp(item.full_name);
          }, 5000);
        }
        if (item.status == "processing") {
          later(() => {
            self.model({ id: params.id });
          }, 5000);
        }
        return item;
      });
  },

  renderTemplate() {
    this.render("verification-intents/show");
  },

  _finishSignUp(accountName) {
    const signupData = PreloadStore.get("signupData");

    const attrs = {
      accountName: accountName,
      accountEmail: signupData.email,
      accountPassword: signupData.password,
      accountUsername: signupData.username,
      accountPasswordConfirm: signupData.password_confirmation,
      accountChallenge: signupData.challenge,
      userFields: signupData.user_fields[0]
    };

    return User.createAccount(attrs)
      .then((result) => {
        if (result.success) {
          later(() => window.location = "/u/account-created", 10000);
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
