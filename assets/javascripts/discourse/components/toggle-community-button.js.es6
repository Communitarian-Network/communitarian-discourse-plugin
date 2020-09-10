import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import showModal from "discourse/lib/show-modal";
import { ajax } from "discourse/lib/ajax";

import setCategoryNotificationLevel from "./set-category-notification-level";

export default Component.extend({
  @discourseComputed("category.notification_level")
  buttonLabel(notificationLevel) {
    let action = this.communityJoined() ? "leave" : "join";
    return `communitarian.community.${action}.label`;
  },

  joinCommunity() {
    ajax(`/c/${this.category.id}/show`).then(({ category }) => {
      let tenets = category.custom_fields.tenets_raw || "";
      if (tenets.length > 0) {
        showModal("community-tenets-modal").setTenets(tenets);
      }
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
