// One-shot smart nav (left): focus the neighbor pane, or at the edge spill
// to tab.prev. Opened by ctrl-h; its siblings nav-* differ only in these two names.

import { View, div } from "gpui-kit";
import { focused, run, props, closeOverlay } from "herdr";

const DIRECTION = "left";
const SPILL = "tab.prev";

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
