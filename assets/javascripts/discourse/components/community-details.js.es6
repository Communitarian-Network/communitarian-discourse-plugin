// import Component from "@ember/component";
// import LoadMore from "discourse/mixins/load-more";
// import UrlRefresh from "discourse/mixins/url-refresh";
// import { on, observes } from "discourse-common/utils/decorators";

// export default Component.extend(UrlRefresh, LoadMore, {
//   actions: {
//     loadMore() {
//       Discourse.updateContextCount(0);
//       this.model.loadMore().then(hasMoreResults => {
//         schedule("afterRender", () => this.saveScrollPosition());
//         if (hasMoreResults && $(window).height() >= $(document).height()) {
//           this.send("loadMore");
//         }
//       });
//     }
//   }
// });
