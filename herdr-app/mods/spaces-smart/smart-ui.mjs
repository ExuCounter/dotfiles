// spaces-smart's own elements, kept out of main.js with its logic (smart.mjs).

import { div, svg } from "gpui-kit";
import { h_flex } from "gpui-base";

const chevron = (folded) => svg(`mods/workspace-chrome/chevron-${folded ? "right" : "down"}.svg`).size(11).flex_none();

// The chevron on a main checkout's row: folds its group, and neither selects
// nor drags the row.
export function foldToggle(key, folded, t, toggle) {
  return div().id(`fold-${key}`).flex_none().p(3).rounded(4).text_color(t.dim)
    .hover((s) => s.bg(t.hover).text_color(t.foreground))
    .on_mouse_down("left", (_e, cx) => { cx.stop_propagation(); toggle(key, cx); })
    .child(chevron(folded));
}

// A repo whose main checkout isn't open: its name, and a chevron that folds it.
export function heading({ heading: repo, folded }, t, toggle) {
  return h_flex().id(`repo-${repo.key}`).h(30).flex_none().px(8).gap(9).items_center().rounded(8)
    .cursor_pointer().hover((s) => s.bg(t.hover))
    .on_click((_e, cx) => toggle(repo.key, cx))
    .child(h_flex().size(18).flex_none().rounded(5).border_1().border_color(t.dim).items_center().justify_center()
      .text_size(10.5).font_bold().text_color(t.dim).child([...repo.name][0]?.toUpperCase() ?? "?"))
    .child(div().flex_1().min_w(0).truncate().text_color(t.muted).child(repo.name))
    .child(div().flex_none().p(3).text_color(t.dim).child(chevron(folded)));
}
