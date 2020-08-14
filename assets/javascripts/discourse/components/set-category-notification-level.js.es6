import Component from "@ember/component";
import { ajax } from "discourse/lib/ajax";

export default Component.extend({
  actions: {
    clickLeaveCommunityButton() {
      ajax(`/category/${this.category.id}/notifications`, {
        type: "POST",
        data: { notification_level: this.notificationLevel }
      }).then(_ => {
        this.category.notification_level = this.notificationLevel;
      });
    }
}});
