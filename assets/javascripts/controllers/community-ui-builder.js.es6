import I18n from "I18n";
import Controller from "@ember/controller";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import DiscourseURL from "discourse/lib/url";
import { action } from "@ember/object";
import { extractError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";

export default Controller.extend(ModalFunctionality, {
  saving: false,
  deleting: false,
  hiddenTooltip: true,

  init() {
    this._super(...arguments);
  },

  onShow() {
    this.titleChanged();
    this.set("codeMaxLength", this.siteSettings.community_code_maxlength || 5);
    this.set("hiddenTooltip", true);
  },

  @discourseComputed("model.{id,name}")
  title(model) {
    if (model.id) {
      return I18n.t("category.edit_dialog_title", {
        categoryName: model.name
      });
    }
    return I18n.t("category.create");
  },

  @observes("title")
  titleChanged() {
    this.set("modal.title", this.title);
  },

@discourseComputed("saving", "model.name", "model.color", "model.custom_fields.introduction_raw",
  "model.custom_fields.community_code", "deleting")
  disabled(saving, name, color, introduction, code, deleting) {
    if (saving || deleting) return true;
    if (!name) return true;
    if (!introduction) return true;
    if (!color) return true;
    if (!code) return true;
    return false;
  },

  @discourseComputed("model.isUncategorizedCategory", "model.id")
  showDescription(isUncategorizedCategory, categoryId) {
    return !isUncategorizedCategory && categoryId;
  },

  @discourseComputed("saving", "deleting")
  deleteDisabled(saving, deleting) {
    return deleting || saving || false;
  },

  @discourseComputed("name")
  categoryName(name) {
    name = name || "";
    return name.trim().length > 0 ? name : I18n.t("preview");
  },

  @discourseComputed("saving", "model.id")
  saveLabel(saving, id) {
    if (saving) return "saving";
    return id ? "category.save" : "category.create";
  },

  @discourseComputed("model.uploaded_logo.url")
  logoImageUrl(uploadedLogoUrl) {
    return uploadedLogoUrl || "";
  },

  @action
  showCategoryTopic() {
    window.open(this.get("model.topic_url"), "_blank").focus();
    return false;
  },

  actions: {
    saveCategory() {
      const model = this.model;
      const parentCategory = this.site.categories.findBy(
        "id",
        parseInt(model.parent_category_id, 10)
      );

      this.set("saving", true);
      model.set("parentCategory", parentCategory);

      model
        .save()
        .then(result => {
          this.set("saving", false);
          this.send("closeModal");
          model.setProperties({
            slug: result.category.slug,
            id: result.category.id
          });
          DiscourseURL.redirectTo(`/c/${Category.slugFor(model)}/${model.id}`);
        })
        .catch(error => {
          this.flash(extractError(error), "error");
          this.set("saving", false);
        });
    },

    coverImageUploadDone(upload) {
      this.set("model.uploaded_logo", upload);
    },

    coverImageUploadDeleted() {
      this.set("model.uploaded_logo");
    },

    deleteCategory() {
      this.set("deleting", true);

      this.send("hideModal");
      bootbox.confirm(
        I18n.t("category.delete_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            this.model.destroy().then(
              () => {
                // success
                DiscourseURL.redirectTo("/categories");
              },
              error => {
                this.flash(extractError(error), "error");
                this.send("reopenModal");
                this.displayErrors([I18n.t("category.delete_error")]);
                this.set("deleting", false);
              }
            );
          } else {
            this.send("reopenModal");
            this.set("deleting", false);
          }
        }
      );
    },

    toggleDeleteTooltip() {
      this.toggleProperty("hiddenTooltip");
    },
  },
});
