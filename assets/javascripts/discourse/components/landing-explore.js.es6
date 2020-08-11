import Component from "@ember/component";
import getURL from "discourse-common/lib/get-url";

export default Component.extend({
  classNames: ["landing-explore"],
  screenExampleUrl: getURL("/plugins/communitarian/images/screen-example.png"),
});
