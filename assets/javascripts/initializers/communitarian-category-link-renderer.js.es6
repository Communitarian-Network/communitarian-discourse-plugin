import { withPluginApi } from "discourse/lib/plugin-api";
import getURL from "discourse-common/lib/get-url";
import { get } from "@ember/object";
import { isRTL } from "discourse/lib/text-direction";
import { iconHTML } from "discourse-common/lib/icon-library";
import Category from "discourse/models/category";
import { escapeExpression } from "discourse/lib/utilities";

function createCategoryDialogsLinkRenderer(api) {
  api.replaceCategoryLinkRenderer(categoryDialogsLinkRenderer);
}

function categoryStripe(color, classes) {
  var style = color ? "style='background-color: #" + color + ";'" : "";
  return "<span class='" + classes + "' " + style + "></span>";
}

let _extraIconRenderers = [];

export function addExtraIconRenderer(renderer) {
  _extraIconRenderers.push(renderer);
}

//Override defaultCategoryLinkRenderer due to the fact that link to category need to set as dialogs
function categoryDialogsLinkRenderer(category, opts) {
  let descriptionText = get(category, "description_text");
  let restricted = get(category, "read_restricted");
  let url = opts.url
    ? opts.url
    : getURL(`/c/${Category.slugFor(category)}/${get(category, "id")}/l/dialogs`);
  let href = opts.link === false ? "" : url;
  let tagName = opts.link === false || opts.link === "false" ? "span" : "a";
  let extraClasses = opts.extraClasses ? " " + opts.extraClasses : "";
  let color = get(category, "color");
  let html = "";
  let parentCat = null;
  let categoryDir = "";

  if (!opts.hideParent) {
    parentCat = Category.findById(get(category, "parent_category_id"));
  }

  const categoryStyle =
    opts.categoryStyle || Discourse.SiteSettings.category_style;
  if (categoryStyle !== "none") {
    if (parentCat && parentCat !== category) {
      html += categoryStripe(
        get(parentCat, "color"),
        "badge-category-parent-bg"
      );
    }
    html += categoryStripe(color, "badge-category-bg");
  }

  let classNames = "badge-category clear-badge";
  if (restricted) {
    classNames += " restricted";
  }

  let style = "";
  if (categoryStyle === "box") {
    style = `style="color: #${get(category, "text_color")};"`;
  }

  html +=
    `<span ${style} ` +
    'data-drop-close="true" class="' +
    classNames +
    '"' +
    (descriptionText ? 'title="' + descriptionText + '" ' : "") +
    ">";

  let categoryName = escapeExpression(get(category, "name"));

  if (Discourse.SiteSettings.support_mixed_text_direction) {
    categoryDir = isRTL(categoryName) ? 'dir="rtl"' : 'dir="ltr"';
  }

  if (restricted) {
    html += iconHTML("lock");
  }
  _extraIconRenderers.forEach(renderer => {
    const iconName = renderer(category);
    if (iconName) {
      html += iconHTML(iconName);
    }
  });
  html += `<span class="category-name" ${categoryDir}>${categoryName}</span>`;
  html += "</span>";

  if (opts.topicCount && categoryStyle !== "box") {
    html += buildTopicCount(opts.topicCount);
  }

  if (href) {
    href = ` href="${href}" `;
  }

  extraClasses = categoryStyle ? categoryStyle + extraClasses : extraClasses;

  let afterBadgeWrapper = "";
  if (opts.topicCount && categoryStyle === "box") {
    afterBadgeWrapper += buildTopicCount(opts.topicCount);
  }
  return `<${tagName} class="badge-wrapper ${extraClasses}" ${href}>${html}</${tagName}>${afterBadgeWrapper}`;
}

export default {
  name: "communitarian-category-link-renderer",
  initialize(_container) {
    withPluginApi("0.8.31", createCategoryDialogsLinkRenderer);
  },
};
