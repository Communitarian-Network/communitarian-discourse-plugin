import DiscourseRoute from "discourse/routes/discourse";
import { later } from "@ember/runloop";
import PreloadStore from "discourse/lib/preload-store";
import User from "discourse/models/user";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default DiscourseRoute.extend({
  model(params) {
    self = this;
    return this.store.find("verification-intent", params.id, { backgroundReload: true }).then(item => {
      if (item.status == "succeeded") {
        this._finishSignUp(item.full_name);
      }
      if (item.status == "processing") {
        later(function() {
          self.model({ id: params.id });
        }, 3000);
      }
      return item;
    })
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
      accountChallenge: signupData.challenge
    };

    return User.createAccount(attrs)
      .then(result => {
        if (result.success) {
          later(() => window.location = "/u/account-created", 5000);
        } else {
          popupAjaxError(result);
        }
      })
      .catch(error => {
        window.location.reload();
      });;
  },

  actions: {
    error(error) {
      window.location = "/";
    }
  },
});
