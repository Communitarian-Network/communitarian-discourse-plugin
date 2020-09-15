import { inject as service } from "@ember/service";
import { inject as controller } from "@ember/controller";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setDefaultHomepage } from "discourse/lib/utilities";
import DiscourseURL from "discourse/lib/url";
import TopicController from "discourse/controllers/topic";
import discourseComputed from "discourse-common/utils/decorators";
import { registerUnbound } from "discourse-common/lib/helpers";
import { gt } from "@ember/object/computed";
import { SEARCH_PRIORITIES } from "discourse/lib/constants";
import showModal from "discourse/lib/show-modal";
import { reopenWidget } from "discourse/widgets/widget";
import CreateAccount from "../modifications/controllers/create_account";
import HeaderButtons from "../modifications/widgets/header-buttons";

import ResolutionController from "../controllers/resolution-controller";
import getResolutionPeriod from "../discourse/components/get-resolution-period";

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

  registerUnbound("get-percent-width", function(currentValue, maxValue) {
    return `width: ${maxValue ? (currentValue / maxValue) * 100 : 0}%`;
  });

  const getFormattedDialogDate = (val) => {
    if (val) {
      var date = new Date(val);
      return moment(date).format("MMM ‘DD");
    }
  }

  api.modifyClass("component:topic-list", {
    listTitle: "communitarian.dialog.header_title",
  });

  api.modifyClass("component:topic-list-item", {
    init() {
      this._super(...arguments);
      this.set("topic.bumped_at", getFormattedDialogDate(this.topic.bumped_at));
    },
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

    actions: {
      goToResolutionsPage() {
        DiscourseURL.routeTo(`${window.location.pathname.replace('/l/dialogs','')}`);
      },

      goToDialogsPage() {
        DiscourseURL.routeTo(`${window.location.pathname}/l/dialogs`);
      },
    }
  });

  api.modifyClass("controller:topic", {
    @discourseComputed()
    isAuthorized() {
      return !!this.currentUser;
    },

    @discourseComputed("postsToRender.posts")
    isResolutionPage(posts) {
      return posts.length && posts[0].polls;
    },

    @discourseComputed("postsToRender.posts")
    actionPeriod(posts) {
      if (!posts.length || (posts[0].polls && !posts[0].polls.length)) {
        return false;
      }

      const post = posts[0];
      const poll = post.polls[0];
      const created = moment(post.created_at);
      const closed = moment(poll.close);

      return getResolutionPeriod(created, closed);
    }
  });

  api.modifyClass("controller:discovery", {
    discoveryTopics: controller("discovery/topics"),
    router: service(),

    @discourseComputed("discoveryTopics.model.dialogs")
    dialogs(dialogs) {
      return dialogs;
    },

    @discourseComputed("router.currentRoute.localName")
    isResolutionsPage(currentRouteName) {
      return currentRouteName === "category";
    },

    actions: {
      goToDialogsPage() {
        DiscourseURL.routeTo(`${window.location.pathname}/l/dialogs`);
      },
    }
  });

  api.modifyClass("controller:account-created-index", {
    @discourseComputed("accountCreated.billing_address")
    isUnknownAddress(billing_address) {
      return billing_address === "unknown";
    },
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

  api.modifyClass("controller:create-account", CreateAccount);

  api.modifyClass("route:discovery-categories", {
    actions: {
      createCategory() {
        openNewCategoryModal(this);
      }
    }
  });

  reopenWidget("header-buttons", HeaderButtons);
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

function customizeTopicController() {
  TopicController.reopen(ResolutionController);
}

export default {
  name: "communitarian",

  initialize(container) {
    withPluginApi("0.8.31", initializeCommunitarian);
    const stripePublicKey = container.lookup("site-settings:main").communitarian_stripe_public_key;
    if (stripePublicKey && typeof(Stripe) !== "undefined") window.stripe = Stripe(stripePublicKey);
    const currentUser = container.lookup("current-user:main");
    if (!currentUser || !currentUser.homepage_id) setDefaultHomepage("home");
    withPluginApi("0.8.31", customizeTopicController);
  },
};
