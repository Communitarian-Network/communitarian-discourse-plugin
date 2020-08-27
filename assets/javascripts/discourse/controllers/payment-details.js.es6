import I18n from "I18n";
import Controller from "@ember/controller";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { throttle } from "@ember/runloop";

export default Controller.extend({
  @discourseComputed("name", "loading")
  submitDisabled(name, loading) {
    return (
      loading ||
      !name.length
    );
  },

  onShow() {
    window.w = this;

    this.setProperties({
      loading: false,
      name: "",
    });
  },

  actions: {
    submitPaymentDetails() {
      window.q = this;
      console.log(`changeVerificationChoice: ${value}`)
    },
  }
});
