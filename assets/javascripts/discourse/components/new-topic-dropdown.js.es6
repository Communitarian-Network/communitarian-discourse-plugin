import I18n from "I18n";
import { computed } from "@ember/object";
import showModal from "discourse/lib/show-modal";
import DropdownSelectBox from "select-kit/components/dropdown-select-box";

export default DropdownSelectBox.extend({
  classNames: ["new-topic-dropdown", "categories-admin-dropdown"],

  selectKitOptions: {
    icon: "reply",
    title: "New",
    showCaret: true
  },

  content: computed(function() {
    const items = [];

    items.push({
      id: "createResolution",
      name: I18n.t("communitarian.resolution.new_button"),
      icon: "bars"
    });

    let allowedToCreateTopic = this.get("createTopicButtonDisabled") !== true || this.get("canCreateTopic") === true || this.get("createTopicDisabled") !== true;

    if (allowedToCreateTopic) {
      items.push({
        id: "createDialog",
        name: I18n.t("communitarian.dialog.new_button"),
        icon: "far-comment"
      });
    }

    return items;
  }),

  createResolution() {
    showModal("resolution-ui-builder")._setupPoll();
  },

  createDialog() {
    this.createTopic();
  },

  actions: {
    onChange(action) {
      this[action]();
    }
  }
});
