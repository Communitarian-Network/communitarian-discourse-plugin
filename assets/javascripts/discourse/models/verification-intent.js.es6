import discourseComputed from "discourse-common/utils/decorators";
import RestModel from "discourse/models/rest";

export default RestModel.extend({
  status: "processing",
  error: "",
  verification_url: "",

  @discourseComputed("status")
  processing(status) {
    return status === "processing";
  },

  @discourseComputed("status")
  requiresAction(status) {
    return status === "requires_action";
  },

  @discourseComputed("status")
  canceled(status) {
    return status === "canceled";
  },

  @discourseComputed("status")
  succeeded(status) {
    return status === "succeeded";
  },
});
