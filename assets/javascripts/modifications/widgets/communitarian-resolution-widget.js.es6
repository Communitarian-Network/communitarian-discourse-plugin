import { createWidget } from 'discourse/widgets/widget';
import Post from "discourse/models/post";

createWidget("communitarian-resolution-widget", {
  html(resolution) {
    this.model = Post.create(resolution.recent_resolution_post);
    return this.attach("post-contents", this.model);
  },
});
