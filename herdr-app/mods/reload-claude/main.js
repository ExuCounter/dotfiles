// One-shot: run /reload-skills and /reload-plugins in every Claude session that is
// waiting for input, then close. Opened by ctrl-=.
//
// The popup closes last: closing it ends the mod and cancels its pending work.
// Sessions come from `hc ls`: agents() is empty in a one-shot popup. Commands are
// typed as keys: `hc send` wraps text in an <hc> tag, which Claude reads as a
// message. ctrl+s stashes a half-typed draft, and Claude restores it after the
// command runs. Working and blocked sessions are skipped: keys would land in their
// prompts.

import { View, div } from "gpui-kit";
import { checking, hc, notify, props, closeOverlay } from "herdr";

const COMMANDS = ["/reload-skills", "/reload-plugins"];

async function reload(address) {
  for (const command of COMMANDS) {
    await hc(["keys", address, "ctrl+s"]);
    await hc(["keys", address, ...command.split(""), "enter"]);
    await hc(["wait", address, "--timeout", "10"]);
  }
}

async function reloadAll() {
  const { terminals } = JSON.parse((await hc(["ls", "--json"])).stdout);
  const claudes = terminals.filter((terminal) => terminal.agent === "claude-code");
  const ready = claudes.filter((terminal) => terminal.status === "idle" || terminal.status === "done");
  for (const terminal of ready) await reload(terminal.address);
  const skipped = claudes.length - ready.length;
  notify({
    title: `Reloaded ${ready.length} Claude session${ready.length === 1 ? "" : "s"}`,
    body: skipped ? `${skipped} busy, skipped` : undefined,
    level: "success",
    timeout: 4,
  });
}

export default class ReloadClaude extends View {
  init(_props, _cx) {
    if (checking()) return;
    const overlay = props()?.overlay;
    reloadAll().finally(() => { if (overlay) closeOverlay(overlay); });
  }

  render() {
    return div();
  }
}
