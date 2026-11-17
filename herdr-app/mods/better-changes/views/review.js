// Reviewing file by file from the diff tab: J and K, or the next-file and prev-file commands
// for a keys.json binding, step through the changed files in the sidebar's
// order, committed and merge request files included, and v marks one viewed. A mark holds the
// file's status and line counts, so a file that changes again after it was viewed shows as not
// viewed.
import { shared, setShared, spaces } from "herdr";
import { fileTree } from "../git/model.js";

const VIEWED = "better-changes.viewed";

const statsOf = (file, scope) =>
  scope === "staged" ? file.stagedStats : scope === "unstaged" ? file.unstagedStats : file;
const statusOf = (file, scope) =>
  scope === "staged" ? file.stagedStatus : scope === "unstaged" ? file.unstagedStatus : file.status;

export const reviewMethods = {
  // The files as the sidebar lists them: conflicts, staged, unstaged; each group flat or as a tree.
  reviewOrder() {
    const branch = this.ahead("branch");
    const committed = this.ahead("committed");
    const groups = [
      ["conflict", this.files.filter((f) => f.conflict)],
      ["staged", this.files.filter((f) => f.staged)],
      ["unstaged", this.files.filter((f) => f.unstaged && !f.conflict)],
      ["committed", committed && committed.base !== branch?.base ? committed.files : []],
      ["branch", branch?.files ?? []],
    ];
    return groups.flatMap(([scope, files]) => {
      const ordered =
        this.view === "flat"
          ? files
          : fileTree(files).filter((row) => row.kind === "file").map((row) => row.file);
      return ordered.map((file) => ({ file, scope }));
    });
  },

  stepFile(direction, cx, { unviewed = false } = {}) {
    const order = this.reviewOrder();
    if (!order.length) return;
    const at = order.findIndex((e) => e.file.path === this.path && e.scope === this.scope);
    for (let step = 1; step <= order.length; step++) {
      const index = at + direction * step;
      if (index < 0 || index >= order.length) return;
      const entry = order[index];
      if (unviewed && this.isViewed(entry.file, entry.scope)) continue;
      this.pick(entry.file, entry.scope, cx);
      return;
    }
  },

  viewedMarks() {
    return (shared(VIEWED) ?? {})[this.root] ?? {};
  },

  loadViewed() {
    let saved = {};
    try {
      saved = JSON.parse(localStorage.getItem("viewed") ?? "{}") ?? {};
    } catch {
      // A broken saved copy only loses the marks.
    }
    setShared(VIEWED, saved);
  },

  fingerprint(file, scope) {
    const stats = statsOf(file, scope) ?? {};
    return `${statusOf(file, scope) ?? ""}:${stats.add ?? 0}:${stats.del ?? 0}`;
  },

  isViewed(file, scope) {
    return this.viewedMarks()[`${scope}:${file.path}`] === this.fingerprint(file, scope);
  },

  toggleViewed(cx) {
    const file = ["committed", "branch"].includes(this.scope)
      ? this.commitFile
      : this.files.find((f) => f.path === this.path);
    if (!file || !["staged", "unstaged", "conflict", "committed", "branch"].includes(this.scope)) return;
    const key = `${this.scope}:${file.path}`;
    const marks = { ...this.viewedMarks() };
    const viewed = !this.isViewed(file, this.scope);
    if (viewed) marks[key] = this.fingerprint(file, this.scope);
    else delete marks[key];
    const all = { ...(shared(VIEWED) ?? {}), [this.root]: marks };
    setShared(VIEWED, all);
    localStorage.setItem("viewed", JSON.stringify(all));
    if (viewed) this.stepFile(1, cx, { unviewed: true });
    cx.notify();
  },

  reviewProgress() {
    const order = this.reviewOrder();
    const viewed = order.filter((e) => this.isViewed(e.file, e.scope)).length;
    return { viewed, total: order.length };
  },

  // Every copy of the mod hears a key's command; the diff tab of the space on screen acts.
  reviewsActiveSpace() {
    return this.mode === "diff" && spaces().find((s) => s.active)?.id === this.diffSpace;
  },

  // A key typed in a text box bubbles up here after the box has seen it; it's text, not a command.
  reviewKey(event, cx) {
    const fromBox = this.keyFromBox;
    this.keyFromBox = false;
    if (fromBox) return;
    if (this.vimKey(event, cx)) return cx.stop_propagation();
    if (event.keystroke !== "v" || this.picked || this.typing()) return;
    this.toggleViewed(cx);
    cx.stop_propagation();
  },
};
