import Component from "@ember/component";
import showModal from "discourse/lib/show-modal";

export default Component.extend({
  actions: {
    createCommunity() {
      openCommunityBuilder(this);
    },
  }
});

export function openCommunityBuilder(context) {
  const model = context.store.createRecord("category", {
    color: "0088CC",
    text_color: "FFFFFF",
    group_permissions: [{ group_name: "everyone", permission_type: 1 }],
    available_groups: ["everyone"],
    allow_badges: true,
    topic_featured_link_allowed: true,
    custom_fields: {
      introduction_raw: "",
      tenets_raw: "",
      community_code: "",
    },
    search_priority: 0
  });

  showModal("community-ui-builder", { model });
}
