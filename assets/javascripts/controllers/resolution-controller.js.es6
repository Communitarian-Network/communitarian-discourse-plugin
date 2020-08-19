import Composer from "discourse/models/composer";
import showModal from "discourse/lib/show-modal";
import I18n from "I18n";

export default {
  actions: {
    // Modification of discourse/app/assets/javascripts/discourse/app/controllers/topic.js:621
    editPost(post) {
      if (!this.currentUser) {
        return bootbox.alert(I18n.t("post.controls.edit_anonymous"));
      } else if (!post.can_edit) {
        return false;
      }

      const composer = this.composer;
      let topic = this.model;
      const composerModel = composer.get("model");
      let editingFirst =
        composerModel &&
        (post.get("firstPost") || composerModel.get("editingFirstPost"));

      let editingSharedDraft = false;
      let draftsCategoryId = this.get("site.shared_drafts_category_id");
      if (draftsCategoryId && draftsCategoryId === topic.get("category.id")) {
        editingSharedDraft = post.get("firstPost");
      }

      const opts = {
        post,
        action: editingSharedDraft ? Composer.EDIT_SHARED_DRAFT : Composer.EDIT,
        draftKey: post.get("topic.draft_key"),
        draftSequence: post.get("topic.draft_sequence")
      };

      if (editingSharedDraft) {
        opts.destinationCategoryId = topic.get("destination_category_id");
      }

      // Next 2 lines is the modification for editing resolutions with custom modal
      if (post.polls && post.polls.length > 0) {
        showModal("resolution-ui-builder")._setupPoll(post.id);
      } else if (editingFirst) {
        // Cancel and reopen the composer for the first post
        composer.cancelComposer().then(() => composer.open(opts));
      } else {
        composer.open(opts);
      }
    },
  },
};
