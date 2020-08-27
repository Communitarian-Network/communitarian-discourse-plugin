import Controller from "@ember/controller";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import showModal from "discourse/lib/show-modal";

export default Controller.extend({
  @discourseComputed("verificationChoice", "loading")
  submitDisabled(verificationChoice, loading) {
    console.log(`submitDisabled`);

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
      window.q = this;
      this.set("verificationChoice", value);
      console.log(`changeVerificationChoice: ${value}`)
    },
    showNextStep() {
      this.set("loading", true);
      console.log(`showNextStep: ${this.get("verificationChoice")}`);
      if(this.get("verificationChoice") == "card") {
        showModal("payment-details");
      } else {
        console.log(`redirect to Stripe Identity`);
      }
    }
  }
});
