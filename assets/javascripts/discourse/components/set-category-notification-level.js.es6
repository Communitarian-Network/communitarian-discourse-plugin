import { ajax } from "discourse/lib/ajax";

export default function setCategoryNotificationLevel(category, notificationLevel) {
  return ajax(`/category/${category.id}/notifications`, {
    type: "POST",
    data: { notification_level: notificationLevel }
  }).then(response => {
    category.set("notification_level", notificationLevel);
    return response;
  });
};
