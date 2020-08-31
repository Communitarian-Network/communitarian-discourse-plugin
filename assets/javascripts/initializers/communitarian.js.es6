import I18n from "I18n";
import { inject as service } from "@ember/service";
import { inject as controller } from "@ember/controller";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setDefaultHomepage } from "discourse/lib/utilities";
import TopicController from "discourse/controllers/topic";
import ResolutionController from "../controllers/resolution-controller";
import discourseComputed from "discourse-common/utils/decorators";
import { registerUnbound } from "discourse-common/lib/helpers";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { gt } from "@ember/object/computed";
import { SEARCH_PRIORITIES } from "discourse/lib/constants";
import showModal from "discourse/lib/show-modal";
import Site from "discourse/models/site";
import LoginMethod from "discourse/models/login-method";
import { reopenWidget } from "discourse/widgets/widget";

function initializeCommunitarian(api) {
  registerUnbound('compare', function(v1, operator, v2) {
    let operators = {
      '===': (l, r) => l === r,
      '!==': (l, r) => l !== r,
      '>': (l, r) => l > r,
      '>=': (l, r) => l >= r,
      '<':  (l, r) => l < r,
      '<=': (l, r) => l <= r,
    };
    return operators[operator] && operators[operator](v1, v2);
  });

  registerUnbound('getPercentWidth', function(currentValue, maxValue) {
    return `width: ${maxValue ? (currentValue / maxValue) * 100 : 0}%`;
  });

  api.modifyClass("controller:navigation/categories", {
    router: service(),

    @discourseComputed("router.currentRoute.localName")
    isCommunitiesPage(currentRouteName) {
      return currentRouteName === "categories";
    },
  });

  api.modifyClass("controller:navigation/category", {
    @discourseComputed()
    isAuthorized() {
      return !!this.currentUser;
    },
  });

  api.modifyClass("controller:discovery", {
    discoveryTopics: controller("discovery/topics"),
    router: service(),

    @discourseComputed("discoveryTopics.model.dialogs")
    dialogs(dialogs) {
      return dialogs;
    },

    @discourseComputed("router.currentRoute.localName")
    isCommunityPage(currentRouteName) {
      return currentRouteName === "category";
    }
  });

  api.modifyClass("controller:discovery:topics", {
    hasDialogs: gt("model.dialogs.length", 0)
  });

  api.modifyClassStatic("model:topic-list", {
    munge(json, store) {
      json.inserted = json.inserted || [];
      json.can_create_topic = json.topic_list.can_create_topic;
      json.more_topics_url = json.topic_list.more_topics_url;
      json.draft_key = json.topic_list.draft_key;
      json.draft_sequence = json.topic_list.draft_sequence;
      json.draft = json.topic_list.draft;
      json.for_period = json.topic_list.for_period;
      json.loaded = true;
      json.per_page = json.topic_list.per_page;
      json.topics = this.topicsFrom(store, json);
      json.dialogs = this.topicsFrom(store, json, { listKey: "dialogs" });

      if (json.topic_list.shared_drafts) {
        json.sharedDrafts = this.topicsFrom(store, json, {
          listKey: "shared_drafts"
        });
      }

      return json;
    }
  });

  api.modifyClass("controller:create-account", {
    onShow() {
      this.setProperties({
        accountUsername: Date.now()
      });
    },

    @discourseComputed
    authButtons() {
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

    fieldsValid() {
      this.clearFlash();

      const validation = [
        this.emailValidation,
        this.nameValidation,
        this.passwordValidation,
        this.userFieldsValidation
      ].find(v => v.failed);

      if (validation) {
        if (validation.message) {
          this.flash(validation.message, "error");
        }

        const element = validation.element;
        if (element.tagName === "DIV") {
          if (element.scrollIntoView) {
            element.scrollIntoView();
          }
          element.click();
        } else {
          element.focus();
        }

        return false;
      }
      return true;
    },

    actions: {
      showNextStep() {
        this.clearFlash();

        if (this.fieldsValid()) {
          if (this.siteSettings.sign_up_with_credit_card && this.siteSettings.sign_up_with_stripe_identity) {
            showModal("choose-verification-way");
          } else if (this.siteSettings.sign_up_with_credit_card){
            if (this.fieldsValid()) {
              showModal("payment-details");
            }
          } else {
            if (new Date() - this._challengeDate > 1000 * this._challengeExpiry) {
              this.fetchConfirmationValue().then(() =>
                this.performAccountCreation()
              );
            } else {
              this.performAccountCreation();
            }
          }
        }
      },
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

function customizeHeaderButtonsWidget() {
  reopenWidget("header-buttons", {
    // start new changes
    linkedinLogin() {
      const linkedinProvider = Site.currentProp("auth_providers").find(provider => provider.name == "linkedin");
      const loginMethod = LoginMethod.create(linkedinProvider);
      loginMethod.doLogin();
    },
    // end new changes

    html(attrs) {
      if (this.currentUser) {
        return;
      }


      const buttons = [];

      // start new changes
      if (this.siteSettings.linkedin_enabled && !(this.siteSettings.sign_up_with_credit_card || this.siteSettings.sign_up_with_stripe_identity)) {
        buttons.push(
          this.attach("button", {
            className: "btn btn-social",
            icon: "fab-linkedin-in",
            label: "login.linkedin.title",
            action: "linkedinLogin"
          })
        );

        return buttons;
      }
      // end new changes

      if (attrs.canSignUp && !attrs.topic) {
        buttons.push(
          this.attach("button", {
            label: "sign_up",
            className: "btn-primary btn-small sign-up-button",
            action: "showCreateAccount"
          })
        );
      }

      buttons.push(
        this.attach("button", {
          label: "log_in",
          className: "btn-primary btn-small login-button",
          action: "showLogin",
          icon: "user"
        })
      );
      return buttons;
    }
  })
}

export default {
  name: "communitarian",

  initialize(container) {
    withPluginApi("0.8.31", initializeCommunitarian);
    const stripePublicKey = container.lookup("site-settings:main").communitarian_stripe_public_key;
    if (stripePublicKey) window.stripe = Stripe(stripePublicKey);
    const currentUser = container.lookup("current-user:main");
    if (!currentUser || !currentUser.homepage_id) setDefaultHomepage("home");
    withPluginApi("0.8.31", customizeTopicController);
    withPluginApi("0.8.31", customizeHeaderButtonsWidget);
  },
};
