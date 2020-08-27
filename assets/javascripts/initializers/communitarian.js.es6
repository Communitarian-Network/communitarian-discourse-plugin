import I18n from "I18n";
import { inject as service } from "@ember/service";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setDefaultHomepage } from "discourse/lib/utilities";
import TopicController from "discourse/controllers/topic";
import ResolutionController from "../controllers/resolution-controller";
import discourseComputed from "discourse-common/utils/decorators";
import { registerUnbound } from "discourse-common/lib/helpers";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { SEARCH_PRIORITIES } from "discourse/lib/constants";
import showModal from "discourse/lib/show-modal";
import Site from "discourse/models/site";
import LoginMethod from "discourse/models/login-method";

function initializeCommunitarian(api) {
  registerUnbound('compare', function(v1, operator, v2) {
    let operators = {
      '===': (l, r) => l === r,
      '!=': (l, r) => l != r,
      '>':  (l, r) => l >  r,
      '>=': (l, r) => l >= r,
      '<':  (l, r) => l <  r,
      '<=': (l, r) => l <= r,
    };
    return operators[operator] && operators[operator](v1, v2);
  });

  api.modifyClass("controller:navigation/categories", {
    router: service(),

    @discourseComputed("router.currentRoute.localName")
    isCommunitiesPage(currentRouteName) {
      return currentRouteName === "categories";
    },
  });

  api.modifyClass("controller:create-account", {
    @discourseComputed
    authButtons() {
      window.q = this;
      let methods = [];

      if(this.get("siteSettings.linkedin_enabled")) {
        const linkedinProvider = Site.currentProp("auth_providers").find(provider => provider.name == "linkedin");
        methods.pushObject(LoginMethod.create(linkedinProvider));
      };

      return methods;
    },

    performAccountCreation() {
      if (this.get("authOptions.email") == this.accountEmail) {
        return this._super(...arguments);
      }

      const data = {
        name: this.accountName,
        email: this.accountEmail,
        password: this.accountPassword,
        username: this.accountUsername,
        password_confirmation: this.accountHoneypot,
        challenge: this.accountChallenge,
        user_fields: this.userFields,
      };

      this.set("formSubmitted", true);
      _createAccount(data, this);
    },

    actions: {
      showNextStep() {
        showModal("choose-verification-way");
      }
    }
  });

  api.modifyClass("route:discovery-categories", {
    actions: {
      createCategory() {
        openNewCategoryModal(this);
      }
    }
  });
}

//Override openNewCategoryModal due to the fact that all members can create category
export function openNewCategoryModal(context) {
  const groups = context.site.groups,
    groupName = groups.findBy("id", 11).name;
  const model = context.store.createRecord("category", {
    color: "0088CC",
    text_color: "FFFFFF",
    group_permissions: [{ group_name: groupName, permission_type: 1 }],
    available_groups: groups.map(g => g.name),
    allow_badges: true,
    topic_featured_link_allowed: true,
    custom_fields: {},
    search_priority: SEARCH_PRIORITIES.normal
  });

  showModal("edit-category", { model }).set("selectedTab", "general");
}

function _createAccount(data, self) {
  return ajax("/communitarian/users/new", { type: "GET", data: data })
    .then(() => {
      _createVerificationIntent(data, self);
    })
    .catch((error) => {
      self.set("formSubmitted", false);
      if (error) {
        self.flash(extractError(error), "error");
      } else {
        bootbox.alert(
          I18n.t("communitarian.verification.error_while_creating")
        );
      }
    });
}

function _createVerificationIntent(data, self) {
  return ajax("/communitarian/verification_intents", {
    type: "POST",
    data: data,
  })
    .then((response) => {
      window.location = response.verification_intent.verification_url;
    })
    .catch((error) => {
      self.set("formSubmitted", false);
      if (error) {
        self.flash(extractError(error), "error");
      } else {
        bootbox.alert(
          I18n.t("communitarian.verification.error_while_creating")
        );
      }
    });
}

function customizeTopicController() {
  TopicController.reopen(ResolutionController);
}

export default {
  name: "communitarian",

  initialize(container) {
    withPluginApi("0.8.31", initializeCommunitarian);
    const currentUser = container.lookup("current-user:main");
    if (!currentUser || !currentUser.homepage_id) setDefaultHomepage("home");
    withPluginApi("0.8.31", customizeTopicController);
  },
};
