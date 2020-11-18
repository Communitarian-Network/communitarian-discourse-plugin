import { withPluginApi } from "discourse/lib/plugin-api";

function createAuthorPostfix(api) {
  api.decorateWidget("poster-name:after", decoratorHelper => decoratorHelper.h(
    "span.post-author-location",
    "from New York, NY"
  ));
}

export default {
  name: "communitarian-post-author-postfix",

  initialize(_container) {
    withPluginApi("0.8.31", createAuthorPostfix);
  },
};
