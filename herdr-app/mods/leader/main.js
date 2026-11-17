// Ctrl-a prefix, as in old herdr: ctrl-a opens this popup, the next key runs
// its command and closes it. Esc or an unbound key just closes it.

import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { run, agents, props, closeOverlay, theme } from "herdr";

const BINDS = [
  ["v", "split right", () => run("pane.split", { direction: "right" })],
  ["s", "split down", () => run("pane.split", { direction: "down" })],
  ["x", "close pane", () => run("pane.close", {})],
  ["shift-x", "close space", () => run("space.close", {})],
  ["h", "prev tab", () => run("tab.prev", {})],
  ["l", "next tab", () => run("tab.next", {})],
  ["k", "prev agent", () => run("agent.prev", {})],
  ["j", "next agent", () => run("agent.next", {})],
  ["w", "picker", () => run("mod.open", { name: "picker" })],
  ["f", "picker", () => run("mod.open", { name: "picker" })],
  ["z", "zoom pane", () => run("pane.zoom", {})],
  ["ctrl-1..9", "focus agent N", null],
];

function agentN(n) {
  const a = agents()[n - 1];
  if (a) run("agent.focus", { terminal: a.address });
}

export default class Leader extends View {
  init(_props, cx) {
    this.handle = cx.focus_handle();
    this.handle.focus();
    cx.timer.after(50, () => this.handle.focus());
  }

  fire(e) {
    const ks = e.keystroke;
    const m = /^ctrl-([1-9])$/.exec(ks);
    if (m) return () => agentN(Number(m[1]));
    const b = BINDS.find(([k, , f]) => f && k === ks);
    return b ? b[2] : null;
  }

  render(cx) {
    const t = theme();
    return v_flex()
      .id("leader")
      .track_focus(this.handle)
      .on_key_down((e, cx) => {
        if (["shift", "control", "alt", "platform", "function"].includes(e.key)) return;
        const f = this.fire(e);
        { const o = props()?.overlay; if (o) closeOverlay(o); }
        if (f) f();
        cx.stop_propagation();
      })
      .size_full()
      .p(14)
      .gap(4)
      .bg(t.popover)
      .text_size(12)
      .child(div().text_size(11).text_color(t.dim).child("ctrl-a …   Esc to cancel"))
      .children(
        BINDS.map(([k, label]) =>
          h_flex().gap(12)
            .child(div().w(80).text_color(t.accent).child(k))
            .child(div().text_color(t.foreground).child(label)),
        ),
      );
  }
}
