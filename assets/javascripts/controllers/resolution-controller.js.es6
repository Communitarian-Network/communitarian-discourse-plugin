import Composer from "discourse/models/composer";
import showModal from "discourse/lib/show-modal";
import I18n from "I18n";

export default {
  actions: {
    editPost(post) {
      if (!this.currentUser) {
        return bootbox.alert(I18n.t("post.controls.edit_anonymous"));
      } else if (!post.can_edit) {
        return false;
      }

      const composer = this.composer;
      const topic = this.model;
      const composerModel = composer.get("model");
      const editingFirst =
        post.get("firstPost") ||
        (composerModel && composerModel.get("editingFirstPost"));

      const draftsCategoryId = this.get("site.shared_drafts_category_id");
      const editingSharedDraft =
        draftsCategoryId === topic.get("category.id")
          ? post.get("firstPost")
          : null;

      const opts = {
        post,
        action: editingSharedDraft ? Composer.EDIT_SHARED_DRAFT : Composer.EDIT,
        draftKey: post.get("topic.draft_key"),
        draftSequence: post.get("topic.draft_sequence"),
      };

      if (editingSharedDraft) {
        opts.destinationCategoryId = topic.get("destination_category_id");
      }

      if (post.polls && post.polls.length > 0) {
        let controller = showModal("resolution-ui-builder");
        controller._setupPoll(post.id);
      } else if (editingFirst) {
        // Cancel and reopen the composer for the first post
        composer.cancelComposer().then(() => composer.open(opts));
      } else {
        composer.open(opts);
      }
    },
  },
};
