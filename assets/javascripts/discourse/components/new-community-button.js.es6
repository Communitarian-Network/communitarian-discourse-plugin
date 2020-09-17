import Component from "@ember/component";
import showModal from "discourse/lib/show-modal";

export default Component.extend({
  actions: {
    clickCreateCommunityButton() {
      openCommunityBulder(this);

    }
  }
});

export function openCommunityBulder(context) {
  const groups = context.site.groups,
    groupName = groups.findBy("id", 0).name;

  const model = context.store.createRecord("category", {
    color: "0088CC",
    text_color: "FFFFFF",
    group_permissions: [{ group_name: groupName, permission_type: 1 }],
    available_groups: groups.map(g => g.name),
    allow_badges: true,
    topic_featured_link_allowed: true,
    custom_fields: {},
    search_priority: 0
  });

  showModal("community-ui-builder", { model });
}
