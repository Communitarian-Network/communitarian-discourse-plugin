import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

import setCategoryNotificationLevel from "./set-category-notification-level";

export default Component.extend({
  @discourseComputed("category.notification_level")
  buttonLabel(notificationLevel) {
    return notificationLevel <= 2
      ? "communitarian.community.join.label"
      : "communitarian.community.leave.label";
  },

  actions: {
    clickToggleCommunityButton() {
      const newNotificationLevel =
        this.category.notification_level <= 2 ? 3 : 1;
      setCategoryNotificationLevel(this.category, newNotificationLevel);
    },
  },
});
