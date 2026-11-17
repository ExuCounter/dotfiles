import { div } from "gpui-kit";
import { shared, setShared, notify, props, closeOverlay } from "herdr";
import * as host from "./hosting.js";
import { msg } from "./lib.js";

// Redline's background watcher: a kept 1×1 window that draws nothing (the launcher opens it).
// Every two minutes, for the repos you opened Redline on (shared "redline.watch"), it posts a
// Herdr toast when
//   - your review is requested on a request,
//   - a pipeline fails on a request you wrote,
//   - someone replies in a thread you wrote in (requests you wrote or review).
// What it has seen lives in shared "redline.seen", so a restart doesn't repeat old news; the
// first look at a repo only records. It stamps shared "redline.watcher" so the launcher knows
// it's alive.

export const WATCH = "redline.watch";     // [{ provider, host, repo, on }]
export const HEARTBEAT = "redline.watcher";
const SEEN = "redline.seen";
const EVERY = 120000;

const toast = (title, body, level = "info") => {
  try { notify({ title, body, level, timeout: 12000, action: { name: "mod.open", args: { name: "redline" } } }); } catch { /* no toast mod */ }
};

export class Watcher {
  constructor(_view, cx) {
    // Disabled: an always-open window blocked clicks in Herdr. A copy that's still open closes itself.
    const id = props()?.overlay;
    if (id) closeOverlay(id);
  }

  tick(cx) {
    if (this.busy) return;
    this.busy = true;
    cx.spawn(async () => {
      try {
        for (const repo of shared(WATCH) ?? []) {
          try { await this.check(repo); } catch (e) { console.log(`redline watch ${repo.repo}: ${msg(e)}`); }
        }
      } finally {
        this.busy = false;
        setShared(HEARTBEAT, Date.now());
      }
    });
  }

  async check(repo) {
    const st = await host.listStatus(repo);
    const me = st.me, mark = repo.provider === "github" ? "#" : "!";
    const key = `${repo.host}/${repo.repo}`;
    const seen = (shared(SEEN) ?? {})[key];
    const first = !seen;
    const next = { requested: [], failed: [], notes: {} };
    for (const [n, s] of Object.entries(st.byNumber)) {
      const asked = s.reviewers.includes(me) && !s.approvedBy.includes(me);
      if (asked) {
        next.requested.push(n);
        if (!first && !seen.requested.includes(n)) toast(`Review requested: ${mark}${n}`, `${s.title} · ${s.author}`);
      }
      if (s.author === me && s.ci === "failed") {
        next.failed.push(n);
        if (!first && !seen.failed.includes(n)) toast(`Pipeline failed: ${mark}${n}`, s.title, "error");
      }
      if (s.author !== me && !s.reviewers.includes(me)) continue;
      // Replies: threads you wrote in, counted; a longer one whose last word isn't yours is news.
      const d = await host.detail(repo, n);
      for (const th of d.threads) {
        if (!th.notes.some((x) => x.author === me)) continue;
        const id = `${n}:${th.id}`, count = th.notes.length, before = seen?.notes?.[id];
        next.notes[id] = count;
        const last = th.notes[count - 1];
        if (!first && before != null && count > before && last.author !== me) {
          toast(`${last.author} replied on ${mark}${n}`, `${th.path ? `${th.path}: ` : ""}${last.body.replace(/\s+/g, " ").slice(0, 160)}`);
        }
      }
    }
    setShared(SEEN, { ...(shared(SEEN) ?? {}), [key]: next });
  }

  render() { return div(); }
}
