import { View } from "gpui-kit";
import { props, nextCommand } from "herdr";
import { Launcher } from "./launcher.js";
import { Review } from "./diff.js";
import { Watcher } from "./watch.js";

// Redline: cmd-shift-f (keys.json "mod.open:redline") opens the launcher; picking a request or
// branch opens a review tab in its worktree, an agent beside this mod as the diff pane
// (props.redline). props.watch: the background watcher behind the notifications.
export default class Redline extends View {
  init(_props, cx) {
    this.handle = cx.focus_handle();
    const p = props() ?? {};
    this.part = p.watch ? new Watcher(this, cx) : p.redline ? new Review(this, cx) : new Launcher(this, cx);
    if (p.redline) cx.spawn(async () => { for (;;) { if ((await nextCommand()) === "focus") this.handle.focus(); } });
  }

  render(cx) { return this.part.render(cx); }
}
