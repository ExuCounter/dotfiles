// One-shot smart nav (right): focus the neighbor pane, or at the edge spill
// to tab.next. Opened by ctrl-l; its siblings nav-* differ only in these two names.

import { View, div } from "gpui-kit";
import { focused, run, props, closeOverlay } from "herdr";

const DIRECTION = "right";
const SPILL = "tab.next";

export default class Nav extends View {
  init(_props, cx) {
    const before = focused()?.pane ?? null;
    run("pane.go", { direction: DIRECTION });
    cx.timer.after(30, () => {
      { const o = props()?.overlay; if (o) closeOverlay(o); }
      if ((focused()?.pane ?? null) === before) run(SPILL, {});
    });
  }

  render() {
    return div();
  }
}
