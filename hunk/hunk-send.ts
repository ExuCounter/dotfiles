/**
 * hunk-send: `S` sends the person's review notes to the session the review was opened
 * from, else the main Claude session, through hunk-send.sh beside this file's real path
 * (the installed copy is a symlink). hunk imports extensions into its own process, so
 * `process.pid` is this window's, the pid `hunk session list` reports for it.
 */
import { execFile } from "node:child_process";
import { realpathSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const script = join(dirname(realpathSync(fileURLToPath(import.meta.url))), "hunk-send.sh");

export default function (hunk: any) {
  let sending = false;
  hunk.registerCommand({ id: "send", title: "Send review notes to the agent", key: "S" }, (ctx: any) => {
    if (sending) {
      ctx.notify("Still sending the last notes.", "info");
      return;
    }
    sending = true;
    return new Promise<void>((resolve) => {
      execFile("bash", [script, String(process.pid)], { cwd: ctx.cwd, timeout: 15000 }, (error, stdout) => {
        sending = false;
        const message = stdout.trim() || error?.message || "hunk-send failed without saying why.";
        ctx.notify(message, error ? "warning" : "info");
        resolve();
      });
    });
  });
}
