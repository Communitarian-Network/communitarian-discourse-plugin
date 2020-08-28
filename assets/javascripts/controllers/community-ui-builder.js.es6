import I18n from "I18n";
import Controller from "@ember/controller";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { throttle } from "@ember/runloop";

export default Controller.extend({
  init() {
    this._super(...arguments);
    this._setupForm();
  },

  _setupForm() {
    this.setProperties({
      formTitle: "communitarian.community.ui_builder.form_title.new",
      buttonLabel: "communitarian.community.ui_builder.create",
      title: "",
      introduction: "",
      tenets: "",
      coverImageUrl: "",

    });
  },

  actions: {
    submitCommunity() {
      alert("Submit");
    },

    coverImageUploadDone() {},

    coverImageUploadDeleted() {},
  },
});
