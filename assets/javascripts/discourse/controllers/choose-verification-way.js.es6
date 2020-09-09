import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import showModal from "discourse/lib/show-modal";

export default Controller.extend({
  createAccount: Ember.inject.controller(),

  @discourseComputed("verificationChoice", "loading")
  submitDisabled(verificationChoice, loading) {
    return (
      loading ||
      !verificationChoice.length
    );
  },

  onShow() {
    this.setProperties({
      loading: false,
      verificationChoice: "",
    });
  },

  actions: {
    changeVerificationChoice(value) {
      this.set("verificationChoice", value);
    },
    showNextStep() {
      this.set("loading", true);
      if (this.get("verificationChoice") === "card") {
        showModal("payment-details");
      } else {
        this.createAccount.performAccountCreation();
      }
    }
  }
});
