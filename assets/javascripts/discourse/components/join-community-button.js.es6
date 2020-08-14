import Component from "@ember/component";
import setCategoryNotificationLevel from "./set-category-notification-level";

export default Component.extend({
  actions: {
    clickJoinCommunityButton() {
      setCategoryNotificationLevel(this.category, 3);
    }
  }
});
