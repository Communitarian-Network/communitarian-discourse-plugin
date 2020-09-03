import Site from "discourse/models/site";
import LoginMethod from "discourse/models/login-method";

export default {
  // start new changes
  linkedinLogin() {
    const linkedinProvider = Site.currentProp("auth_providers").find(provider => provider.name == "linkedin");
    const loginMethod = LoginMethod.create(linkedinProvider);
    loginMethod.doLogin();
  },
  // end new changes

  html(attrs) {
    if (this.currentUser) {
      return;
    }


    const buttons = [];

    // start new changes
    if (this.siteSettings.linkedin_enabled && !(this.siteSettings.sign_up_with_credit_card_enabled || this.siteSettings.sign_up_with_stripe_identity_enabled)) {
      buttons.push(
        this.attach("button", {
          className: "btn btn-social",
          icon: "fab-linkedin-in",
          label: "login.linkedin.title",
          action: "linkedinLogin"
        })
      );

      return buttons;
    }
    // end new changes

    if (attrs.canSignUp && !attrs.topic) {
      buttons.push(
        this.attach("button", {
          label: "sign_up",
          className: "btn-primary btn-small sign-up-button",
          action: "showCreateAccount"
        })
      );
    }

    buttons.push(
      this.attach("button", {
        label: "log_in",
        className: "btn-primary btn-small login-button",
        action: "showLogin",
        icon: "user"
      })
    );
    return buttons;
  }
};
