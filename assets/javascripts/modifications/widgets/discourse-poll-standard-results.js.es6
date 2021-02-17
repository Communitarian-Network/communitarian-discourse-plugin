import evenRound from "discourse/plugins/poll/lib/even-round";
import { h } from "virtual-dom";
import RawHtml from "discourse/widgets/raw-html";

function optionHtml(option) {
  const $node = $(`<span>${option.html}</span>`);

  $node.find(".discourse-local-date").each((_index, elem) => {
    $(elem).applyLocalDates();
  });

  return new RawHtml({ html: `<span>${$node.html()}</span>` });
}

export default {


  html(attrs, state) {
    const { poll } = attrs;
    const options = poll.get("options");

    if (options) {
      const voters = poll.get("voters");
      const isStaff = this.currentUser && (this.currentUser.staff || this.currentUser.admin);

      const ordered = _.clone(options).sort((a, b) => {
        if (a.votes < b.votes) {
          return 1;
        } else if (a.votes === b.votes) {
          if (a.html < b.html) {
            return -1;
          } else {
            return 1;
          }
        } else {
          return -1;
        }
      });

      if (isStaff && !state.loaded) {
        state.voters = poll.get("preloaded_voters");
        state.loaded = true;
      }

      const percentages =
        voters === 0
          ? Array(ordered.length).fill(0)
          : ordered.map(o => (100 * o.votes) / voters);

      const rounded = attrs.isMultiple
        ? percentages.map(Math.floor)
        : evenRound(percentages);

      return ordered.map((option, idx) => {
        const contents = [];
        const per = rounded[idx].toString();
        const chosen = (attrs.vote || []).includes(option.id);

        contents.push(
          h(
            "div.option",
            h("p", [h("span.percentage", `${per}%`), optionHtml(option)])
          )
        );

        contents.push(
          h(
            "div.bar-back",
            h("div.bar", { attributes: { style: `width:${per}%` } })
          )
        );

        if (isStaff) {
          contents.push(
            this.attach("discourse-poll-voters", {
              postId: attrs.post.id,
              optionId: option.id,
              pollName: poll.get("name"),
              totalVotes: option.votes,
              voters: (state.voters && state.voters[option.id]) || []
            })
          );
        }

        return h("li", { className: `${chosen ? "chosen" : ""}` }, contents);
      });
    }
  }
}
