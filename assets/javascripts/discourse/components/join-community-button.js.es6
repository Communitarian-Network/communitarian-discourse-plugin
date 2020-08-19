import Component from "@ember/component";
import setCategoryNotificationLevel from "./set-category-notification-level";

export default Component.extend({
  classNames: ["join-community-button"],
  actions: {
    clickJoinCommunityButton() {
      setCategoryNotificationLevel(this.category, 3);
    }
  }
});
