import I18n from "I18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { computed } from "@ember/object";
import { setting } from "discourse/lib/computed";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["categories-admin-dropdown"],
  classNames: ["categories-admin-dropdown"],

  selectKitOptions: {
    icon: "bars",
    showFullTitle: false,
    autoFilterable: false,
    filterable: false
  },

  content: computed(function() {
    let items = [];
    items.push({
      id: "create-resolution",
      name: I18n.t("communitarian.resolution.new_button"),
      description: I18n.t("category.create_long"),
      icon: "plus"
    });
    items.push({
      id: "create-dialog",
      name: I18n.t("communitarian.dialog.new_button"),
      description: "Hey",
      icon: "plus"
    });
    return items;
  }),

  _onChange(value, item) {
    debugger;
    if (value === "create-resolution") {

    }
    if (item.onChange) {
      item.onChange(value, item);
    } else if (this.attrs.onChange) {
      this.attrs.onChange(value, item);
    }
  }
});
