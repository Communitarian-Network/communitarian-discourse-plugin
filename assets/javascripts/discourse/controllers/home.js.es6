import discourseComputed from "discourse-common/utils/decorators";
import { dasherize } from "@ember/string";

const subcategoryStyleComponentNames = {
  rows: "categories_only",
  rows_with_featured_topics: "categories_with_featured_topics",
  boxes: "categories_boxes",
  boxes_with_featured_topics: "categories_boxes_with_topics",
};

export default Ember.Controller.extend({
  @discourseComputed("model.parentCategory")
  categoryPageStyle(parentCategory) {
    let style = this.site.mobileView
      ? "categories_with_featured_topics"
      : this.siteSettings.desktop_category_page_style;

    if (parentCategory) {
      style =
        subcategoryStyleComponentNames[
          parentCategory.get("subcategory_list_style")
        ] || style;
    }

    const componentName =
      parentCategory && style === "categories_and_latest_topics"
        ? "categories_only"
        : style;
    return dasherize(componentName);
  },

  @discourseComputed("model.categories")
  landingCategories(categories) {
  const landingCategoryIds = this.siteSettings.landing_categories.split("|");

  if (landingCategoryIds) {
    categories = landingCategoryIds.map(scid =>
        categories.findBy("id", parseInt(scid, 10))
      );
  }

    return categories;
  },

  actions: {
    refresh() {
      this.send("triggerRefresh");
    },
  },
});
