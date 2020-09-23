import { withPluginApi } from "discourse/lib/plugin-api";

function createAuthorPrefix(api) {
  api.decorateWidget("poster-name:before", decoratorHelper => decoratorHelper.h(
    "span.post-author-prefix",
    I18n.t("communitarian.post.author_prefix")
  ));
}

export default {
  name: "communitarian-post-author-prefix",

  initialize(_container) {
    withPluginApi("0.8.31", createAuthorPrefix);
  },
};

