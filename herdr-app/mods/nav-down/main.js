// One-shot smart nav (down): focus the neighbor pane, or at the edge step to the
// next row of Better Sidebar's Spaces tree (an agent, or a tab with none),
// else space.next. Opened by ctrl-j; nav-up and nav-down differ only in these names.

import { View, div } from "gpui-kit";
import { focused, run, props, closeOverlay, shared } from "herdr";

const DIRECTION = "down";
const STEP = 1;
const SPILL = "space.next";

function stepRow() {
  const rows = shared("better-sidebar.rows") ?? [];
  if (!rows.length) return run(SPILL, {});
  const now = focused();
  let at = rows.findIndex((row) => (row.pane ? row.pane === now?.pane : row.tab === now?.tab));
  if (at < 0) at = rows.findIndex((row) => row.tab === now?.tab);
  const row = rows[(at + STEP + rows.length) % rows.length];
  if (row.pane) run("pane.focus", { pane: row.pane });
  else {
    run("space.select", { id: row.space });
    run("tab.select", { id: row.tab });
  }
}

export default class Nav extends View {
  init(_props, cx) {
    const before = focused()?.pane ?? null;
    run("pane.go", { direction: DIRECTION });
    cx.timer.after(30, () => {
      { const o = props()?.overlay; if (o) closeOverlay(o); }
      if ((focused()?.pane ?? null) === before) stepRow();
    });
  }

  render() {
    return div();
  }
}
