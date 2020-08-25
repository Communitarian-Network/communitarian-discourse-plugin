import I18n from "I18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { computed } from "@ember/object";
import { setting } from "discourse/lib/computed";
import showModal from "discourse/lib/show-modal";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["categories-admin-dropdown"],
  classNames: ["categories-admin-dropdown"],

  selectKitOptions: {
    icon: "plus",
    showFullTitle: false,
    autoFilterable: false,
    filterable: false
  },

  defaultDropdownActions: {
    createResolution: () => {
      showModal("resolution-ui-builder")._setupPoll();
    },
    createDialog: () => {},
  },

  content: computed(function() {
    let items = [];
    items.push({
      id: "createResolution",
      name: I18n.t("communitarian.resolution.new_button"),
      description: I18n.t("category.create_long"),
      icon: "plus"
    });
    items.push({
      id: "createDialog",
      name: I18n.t("communitarian.dialog.new_button"),
      description: "Hey",
      icon: "plus"
    });
    return items;
  }),

  _onChange(value, item) {
    let onClick = this.get(`${value}Action`);
    if (onClick) {
      onClick();
    } else {
      this.defaultDropdownActions[value]();
    }
  }
});
