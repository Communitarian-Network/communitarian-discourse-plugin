import { withPluginApi } from "discourse/lib/plugin-api";
import User from "discourse/models/user";

function createAuthorPostfix(api) {
  api.decorateWidget("poster-name:after", dec => {
    const username = dec.attrs.username;

    User.findByUsername(username).then(user => {
      const address = user.user_fields["123001"];

      return dec.h("span.post-author-location", "from " + address);
    });
  });
}
export default {
  name: "communitarian-post-author-postfix",
  initialize(_container) {
    withPluginApi("0.8.31", createAuthorPostfix);
  },
};
