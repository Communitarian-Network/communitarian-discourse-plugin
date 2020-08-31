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
      coverImageId: null,
    });
  },

  actions: {
    submitCommunity() {
      const randInt = bound => Math.floor(Math.random() * bound);
      const hexAlphabet = "0123456789ABCDEF";
      const pickRandom = collection => collection[randInt(collection.length)];
      const randomHexString = length => Array.from({ length }, _ => pickRandom(hexAlphabet)).join("");

      ajax("/categories", {
        type: "POST",
        data: {
          name: this.title,
          uploaded_logo_id: this.coverImageId,
          color: randomHexString(6),
          text_color: randomHexString(6),
          permissions: { trust_level_1: 1 },
          allow_badges: false,
          topic_template: "",
          required_tag_group_name: "",
          topic_featured_link_allowed: true,
          search_priority: 0,
          custom_fields: {
            introduction_raw: this.introduction + "\n",
            tenets_raw: this.tenets,
          },
        },
      }).then(({ category }) => {
        window.location.href = `/c/${category.slug}`;
      });
    },

    coverImageUploadDone(upload) {
      this.set("coverImageId", upload.id);
    },

    coverImageUploadDeleted(upload) {
      this.set("coverImageId", null);
    },
  },
});
