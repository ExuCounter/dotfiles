// Reading the folder tree, and Git's view of it, for the focused pane's folder.
import { spaces, panes, focused, exec, watchFolder } from "herdr";
import { PER_FOLDER, parseStatus, sortEntries } from "./model.js";

// Each read of a folder is bounded, and the names come back null-separated, so no file name
// can break the list. Adapted from Herdr's shipped Files mod.
// shortcut: needs `sh`, so a Windows machine shows an error; add a PowerShell listing if one is used.
async function directory(path, on) {
  const script = `n=0; for p in "$1"/* "$1"/.[!.]* "$1"/..?*; do [ -e "$p" ] || [ -L "$p" ] || continue; name=\${p##*/}; [ "$name" = .git ] && continue; if [ -d "$p" ]; then kind=d; else kind=f; fi; printf "%s\\0%s\\0" "$kind" "$name"; n=$((n+1)); [ "$n" -gt ${PER_FOLDER} ] && break; done; test -d "$1"`;
  const r = await exec("sh", ["-c", script, "files", path], { on });
  if (r.code !== 0) throw new Error(r.stderr || "Cannot list this folder.");
  const fields = r.stdout.split("\0");
  const out = [];
  for (let i = 0; i + 1 < fields.length; i += 2)
    out.push({ name: fields[i + 1], dir: fields[i] === "d" });
  return out;
}

export const readMethods = {
  // The focused pane's folder. A file or diff tab has no folder of its own, so looking at
  // one keeps the tree where it was instead of jumping back to the space's.
  location() {
    const space = spaces().find((s) => s.active);
    const f = focused();
    const pane = f?.pane ? panes().find((p) => p.pane === f.pane) : null;
    const on =
      f?.pane === null
        ? f.terminal?.includes("/")
          ? f.terminal.split("/")[0]
          : null
        : (space?.machine ?? null);
    const cwd = pane?.cwd || f?.cwd;
    if (!cwd && this.place?.space === space?.id && this.place?.cwd) return this.place;
    return (this.place = { cwd: cwd || space?.folder, on, space: space?.id });
  },

  placeKey() {
    return JSON.stringify(this.location());
  },

  // A folder's own state is kept, so coming back to it is where you left it.
  refresh(cx) {
    const { cwd, on } = this.location();
    const key = this.placeKey();
    if (key !== this.key) {
      if (this.key) this.saved.set(this.key, { folders: this.folders });
      const kept = this.saved.get(key);
      this.key = key;
      this.root = cwd;
      this.on = on;
      this.entries = new Map();
      this.folders = kept?.folders ?? new Set();
      this.marks = {};
      this.top = null;
      this.treeError = null;
      this.watch(cx);
    }
    if (!cwd || this.loading === key) return;
    const token = key;
    this.loading = key;
    cx.notify();
    cx.spawn(async (cx) => {
      try {
        for (const path of ["", ...this.folders]) {
          if (this.key !== token) return;
          await this.loadFolder(path, cwd, on, token);
        }
        await this.loadMarks(cwd, on, token);
        if (this.key === token) this.treeError = null;
      } catch (e) {
        if (this.key === token) this.treeError = e.message ?? String(e);
      } finally {
        if (this.loading === token) this.loading = null;
        cx.notify();
      }
    });
  },

  async loadFolder(path, root, on, token) {
    const list = await directory(path ? `${root}/${path}` : root, on);
    if (this.key !== token) return;
    this.entries.set(path, sortEntries(list));
  },

  // Writes nothing under .git, or the folder watch would see its own read and refresh again.
  async loadMarks(root, on, token) {
    const top = await exec("git", ["rev-parse", "--show-toplevel"], { cwd: root, on }).catch(
      () => null,
    );
    if (this.key !== token) return;
    if (top?.code !== 0) {
      this.top = null;
      this.marks = {};
      return;
    }
    const status = await exec(
      "git",
      [
        "--no-optional-locks",
        "-c",
        "core.fsmonitor=false",
        "status",
        "--porcelain=v1",
        "-z",
        "--no-renames",
        "--untracked-files=all",
      ],
      { cwd: root, on },
    ).catch(() => null);
    if (this.key !== token) return;
    this.top = top.stdout.trim();
    if (status?.code === 0) this.marks = parseStatus(status.stdout, this.top);
  },

  // A local folder says when it changes; another machine's is read on the timer alone.
  watch(cx) {
    const { root, on, key } = this;
    if (on || !root || this.watched === key) return;
    this.watched = key;
    cx.spawn(async (cx) => {
      try {
        while (this.key === key) {
          await watchFolder(root);
          if (this.key === key) this.refresh(cx);
        }
      } catch {
        // No watcher here: the timer still refreshes.
      }
      if (this.watched === key) this.watched = null;
    });
  },

  toggleFolder(path, cx) {
    if (!this.folders.delete(path)) {
      this.folders.add(path);
      const { root, on, key } = this;
      cx.spawn(async (cx) => {
        try {
          await this.loadFolder(path, root, on, key);
        } catch (e) {
          if (this.key === key) this.treeError = e.message ?? String(e);
        }
        cx.notify();
      });
    }
    cx.notify();
  },

};
