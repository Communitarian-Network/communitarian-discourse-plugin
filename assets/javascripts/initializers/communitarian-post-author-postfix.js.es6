import { withPluginApi } from "discourse/lib/plugin-api";

function createAuthorPostfix(api) {
  api.decorateWidget("poster-name:after", dec => {
    const userCustomFields = dec.attrs.userCustomFields || dec.attrs.user_custom_fields;

    if(userCustomFields && userCustomFields.user_field_123001) {
      return dec.h("span.post-author-location", "from " + userCustomFields.user_field_123001);
    }
  });
}
export default {
  name: "communitarian-post-author-postfix",
  initialize(_container) {
    withPluginApi("0.8.31", createAuthorPostfix);
  },
};
