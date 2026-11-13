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

// The line under a mouse's worktree (`l`: smart.mjs's line(), or null for
// none): its agent's last line, a question in the accent colour, then the
// owl's labels in their tones, dimmed once the owl has gone quiet. Indented
// to the worktree's name.
export function worktreeLine(l, t) {
  if (!l) return [];
  const tones = { green: t.ansi2, red: t.ansi1, blue: t.ansi4, yellow: t.ansi3, dim: t.dim };
  return [h_flex().h(18).flex_none().pl(52).pr(8).gap(6).items_center().text_size(11.5)
    .child(div().flex_1().min_w(0).truncate().text_color(l.ask ? t.accent : t.muted).child(l.msg))
    .children(l.labels.map(({ text, tone }) => div().flex_none().text_color(l.stale ? t.dim : tones[tone] ?? t.muted).child(text)))];
}
