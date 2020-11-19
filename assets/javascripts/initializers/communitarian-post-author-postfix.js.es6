import { withPluginApi } from "discourse/lib/plugin-api";
import User from "discourse/models/user";

function createAuthorPostfix(api) {
  api.decorateWidget("poster-name:after", async dec => {
    const attrs = dec.attrs;
    const user = await User.findByUsername(attrs.username);
    const address = user.user_fields["123001"];
    console.log(address);
    return dec.h("span.post-author-location", address);
  });
}

export default {
  name: "communitarian-post-author-postfix",

  initialize(_container) {
    withPluginApi("0.8.31", createAuthorPostfix);
  },
};
