import Post from "discourse/models/post";
import PostCooked from "discourse/widgets/post-cooked";
import transformPost from "discourse/lib/transform-post";
import DecoratorHelper from "discourse/widgets/decorator-helper";
import { createWidget, applyDecorators, reopenWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import DiscourseURL from "discourse/lib/url";

createWidget("communitarian-resolution-widget", {
  html(resolution) {
    let prevPost;
    let nextPost;

    this.model = Post.create(resolution.recent_resolution_post);

    const transformed = transformPost(
      this.currentUser,
      this.site,
      this.model,
      prevPost,
      nextPost
    );
    transformed.hideMenu = true;

    const postContents = this.attach("post-contents", transformed);
    let result = [this.attach("post-meta-data", transformed)];
    result.push(postContents);

    return result;
  },
});

// copied from discourse/app/assets/javascripts/discourse/app/widgets/post.js:226
function showReplyTab(attrs, siteSettings) {
  return (
    attrs.replyToUsername &&
    (!attrs.replyDirectlyAbove || !siteSettings.suppress_reply_directly_above)
  );
}

reopenWidget("post-contents", {
  // copied from discourse/app/assets/javascripts/discourse/app/widgets/post.js:383
  html(attrs, state) {
    let result = [
      new PostCooked(attrs, new DecoratorHelper(this), this.currentUser)
    ];

    if (attrs.requestedGroupName) {
      result.push(this.attach("post-group-request", attrs));
    }

    result = result.concat(applyDecorators(this, "after-cooked", attrs, state));

    if (attrs.cooked_hidden) {
      result.push(this.attach("expand-hidden", attrs));
    }

    if (!state.expandedFirstPost && attrs.expandablePost) {
      result.push(this.attach("expand-post-button", attrs));
    }

    // custom if statement
    if (attrs.hideMenu) {
      return result;
    }

    const extraState = { state: { repliesShown: !!state.repliesBelow.length } };
    result.push(this.attach("post-menu", attrs, extraState));

    const repliesBelow = state.repliesBelow;
    if (repliesBelow.length) {
      result.push(
        h("section.embedded-posts.bottom", [
          repliesBelow.map(p => {
            return this.attach("embedded-post", p, {
              model: this.store.createRecord("post", p)
            });
          }),
          this.attach("button", {
            title: "post.collapse",
            icon: "chevron-up",
            action: "toggleRepliesBelow",
            actionParam: "true",
            className: "btn collapse-up"
          })
        ])
      );
    }

    return result;
  },
});
