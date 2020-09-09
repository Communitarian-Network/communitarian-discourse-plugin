import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import showModal from "discourse/lib/show-modal";
import { ajax } from "discourse/lib/ajax";

import setCategoryNotificationLevel from "./set-category-notification-level";

export default Component.extend({
  @discourseComputed("category.notification_level")
  buttonLabel(notificationLevel) {
    return this.communityJoined()
      ? "communitarian.community.leave.label"
      : "communitarian.community.join.label";
  },

  joinCommunity() {
    // showModal("community-tenets").setCategory(this.category);
    debugger;
    ajax(`/c/${this.category.slug}`).then((category) => {
      debugger;
      console.log(category.custom);
    });
    setCategoryNotificationLevel(this.category, 3);
  },

  leaveCommunity() {
    setCategoryNotificationLevel(this.category, 1);
  },

  communityJoined() {
    return this.category.notification_level >= 3;
  },

  actions: {
    clickToggleCommunityButton() {
      if (this.communityJoined()) {
        this.leaveCommunity();
      } else {
        this.joinCommunity();
      }
    },
  },
});
