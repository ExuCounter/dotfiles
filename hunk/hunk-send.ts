/**
 * hunk-send: `S` sends the person's review notes to the main Claude session, through
 * hunk-send.sh beside this file's real path (the installed copy is a symlink).
 */
import { execFile } from "node:child_process";
import { realpathSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const script = join(dirname(realpathSync(fileURLToPath(import.meta.url))), "hunk-send.sh");

export default function (hunk: any) {
  let sending = false;
  hunk.registerCommand({ id: "send", title: "Send review notes to the main session", key: "S" }, (ctx: any) => {
    if (sending) {
      ctx.notify("Still sending the last notes.", "info");
      return;
    }
    sending = true;
    return new Promise<void>((resolve) => {
      execFile("bash", [script], { cwd: ctx.cwd, timeout: 15000 }, (error, stdout) => {
        sending = false;
        const message = stdout.trim() || error?.message || "hunk-send failed without saying why.";
        ctx.notify(message, error ? "warning" : "info");
        resolve();
      });
    });
  });
}
