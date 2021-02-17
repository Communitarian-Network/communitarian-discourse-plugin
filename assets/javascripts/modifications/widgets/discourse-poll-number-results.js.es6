import RawHtml from "discourse/widgets/raw-html";
import round from "discourse/lib/round";
import I18n from "I18n";
import { h } from "virtual-dom";

export default {
  html(attrs, state) {
    const { poll } = attrs;

    const isStaff = this.currentUser && (this.currentUser.staff || this.currentUser.admin);
    const totalScore = poll.get("options").reduce((total, o) => {
      return total + parseInt(o.html, 10) * parseInt(o.votes, 10);
    }, 0);

    const voters = poll.get("voters");
    const average = voters === 0 ? 0 : round(totalScore / voters, -2);
    const averageRating = I18n.t("poll.average_rating", { average });
    const contents = [
      h(
        "div.poll-results-number-rating",
        new RawHtml({ html: `<span>${averageRating}</span>` })
      )
    ];

    if (isStaff) {
      if (!state.loaded) {
        state.voters = poll.get("preloaded_voters");
        state.loaded = true;
      }

      contents.push(
        this.attach("discourse-poll-voters", {
          totalVotes: poll.get("voters"),
          voters: state.voters || [],
          postId: attrs.post.id,
          pollName: poll.get("name"),
          pollType: poll.get("type")
        })
      );
    }

    return contents;
  }
}
