import Component from "@ember/component";

export default Component.extend({
  didInsertElement() {
    this._super(...arguments);

    const elements = window.stripe.elements();
    const style = {
      base: {
        color: "#32325d",
        fontFamily: 'Arial, sans-serif',
        fontSmoothing: "antialiased",
        fontSize: "16px",
        "::placeholder": {
        }
      },
      invalid: {
        fontFamily: 'Arial, sans-serif',
        color: "#fa755a",
      }
    };
    window.card = elements.create("card", { style: style });
    window.card.mount("#card-element");

    $(this.element).on("keydown.discourse-payment-details", e => {
      if (!this.disabled && e.keyCode === 13) {
        e.preventDefault();
        e.stopPropagation();
        this.action();
        return false;
      }
    });
  },

  willDestroyElement() {
    this._super(...arguments);

    $(this.element).off("keydown.discourse-payment-details");
    window.card.unmount();
  }
});
