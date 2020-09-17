import Component from "@ember/component";
import getURL from "discourse-common/lib/get-url";

export default Component.extend({
  classNames: ["section-about"],
  photoUrl: getURL("/plugins/communitarian/images/AmitaiEtzioni.jpg"),
});
