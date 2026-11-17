// One-shot: focus the next agent blocked on you, after the focused one in
// agents() order (wraps), then close. Opened by ctrl-w.

import { View, div } from "gpui-kit";
import { agents, run, props, closeOverlay } from "herdr";

export default class NextWaiting extends View {
  init(_props, _cx) {
    const all = agents();
    const at = all.findIndex((a) => a.focused);
    const order = [...all.slice(at + 1), ...all.slice(0, at + 1)];
    const next = order.find((a) => a.status === "blocked" && !a.focused);
    { const o = props()?.overlay; if (o) closeOverlay(o); }
    if (next) run("agent.focus", { terminal: next.address });
  }

  render() {
    return div();
  }
}
