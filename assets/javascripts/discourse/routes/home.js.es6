import CategoryList from "discourse/models/category-list";

export default Ember.Route.extend({
  findCategories() {
    let style =
      !this.site.mobileView && this.siteSettings.desktop_category_page_style;

    if (style === "categories_and_latest_topics") {
      return this._findCategoriesAndTopics("latest");
    } else if (style === "categories_and_top_topics") {
      return this._findCategoriesAndTopics("top");
    }

    return CategoryList.list(this.store);
  },

  model() {
    return this.findCategories().then((model) => {
      const tracking = this.topicTrackingState;
      if (tracking) {
        tracking.sync(model, "categories");
        tracking.trackIncoming("categories");
      }
      return model;
    });
  },

  actions: {
    triggerRefresh() {
      this.refresh();
    },
  },
});
