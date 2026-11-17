// The diff tab's keys in a window over the diff, opened with ? or the bar's Keys button.
import { div } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { theme } from "herdr";
import { TEXT, BarButton } from "./ui.js";

const GROUPS = [
  [
    "Files",
    [
      ["J  K", "Next / previous file"],
      ["v", "Mark viewed, go to the next unviewed file"],
      ["⌃H  ⌃L", "Tab to the left / right"],
    ],
  ],
  [
    "Moving",
    [
      ["j  k", "Line down / up"],
      ["gg  G", "Top / bottom"],
      ["⌃D  ⌃U", "20 lines down / up"],
      ["]  [", "Next / previous change"],
      ["f", "Whole file / changes only"],
    ],
  ],
  [
    "Comments",
    [
      ["⇧V", "Select lines from the cursor, then j / k"],
      ["c  ↩", "Comment on the line or selection"],
      ["⌘↩  ⇧⌘↩", "Send it to the agent / post it on GitLab"],
      ["esc", "Cancel"],
    ],
  ],
  [
    "Claude's review",
    [
      ["⇧R", "Review the change; findings land on their lines"],
      ["a", "Ask about the line or selection; the answer shows under it"],
      ["cn  cN", "Next / previous thread or finding"],
    ],
  ],
  [
    "Merge request threads",
    [
      ["cn  cN", "Next / previous thread"],
      ["t", "The review queue, or the line's threads"],
      ["⇧T", "Hide / show the thread panel"],
      ["r", "Reply to the thread on the line"],
    ],
  ],
];

export const helpMethods = {
  toggleHelp(cx) {
    this.helpOpen = !this.helpOpen;
    cx.notify();
  },

  KeysButton() {
    return BarButton({
      id: "keys-help",
      icon: "keyboard",
      active: this.helpOpen,
      tooltip: "Keys (?)",
      onClick: (cx) => this.toggleHelp(cx),
      children: [div().child("Keys")],
    });
  },

  renderHelp() {
    const t = theme();
    const card = v_flex()
      .id("keys-card")
      .w(440)
      .max_h_full()
      .overflow_y_scroll()
      .p(16)
      .gap(14)
      .rounded(10)
      .border_1()
      .border_color(t.border)
      .bg(t.raised)
      .shadow_lg()
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .child(
        h_flex()
          .items_center()
          .child(div().flex_1().font_semibold().child("Keys"))
          .child(div().text_size(TEXT.caption).text_color(t.dim).child("? or esc to close")),
      )
      .children(
        GROUPS.map(([title, keys]) =>
          v_flex()
            .gap(4)
            .child(div().text_size(TEXT.caption).text_color(t.dim).child(title))
            .children(
              keys.map(([key, what]) =>
                h_flex()
                  .gap(12)
                  .text_size(TEXT.small)
                  .child(div().w(80).flex_none().font_semibold().text_color(t.accent).child(key))
                  .child(div().flex_1().child(what)),
              ),
            ),
        ),
      );
    return div()
      .id("keys-help-backdrop")
      .absolute()
      .inset_0()
      .flex()
      .items_center()
      .justify_center()
      .p(16)
      .bg(`${t.background}b0`)
      .on_mouse_down("left", (_e, cx) => this.toggleHelp(cx))
      .child(card);
  },
};
