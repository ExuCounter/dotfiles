import { div } from "gpui-kit";
import { v_flex, h_flex, TextareaState, Textarea, TextView, Scrollbar, v_virtual_list, Popover } from "gpui-base";
import { exec, agents, theme, settings, props, hc, shared, setShared, readTextFile, run } from "herdr";
import { READ, git, gitError, diffRows, numstat, msg } from "./lib.js";
import * as host from "./hosting.js";
import { tokens, langOf } from "./highlight.js";
import { JOB_LOOK } from "./panels.js";
import { councilTask } from "./launcher.js";

const ROW = 20;
const ago = (t) => {
  const s = (Date.now() - t) / 1000;
  return !t ? "" : s < 3600 ? `${Math.max(1, Math.round(s / 60))}m` : s < 86400 ? `${Math.round(s / 3600)}h` : `${Math.round(s / 86400)}d`;
};
// A diff line's keys for matching comments: removed lines live on the old side, the rest on the new.
const keysOf = (x) => (x.kind === "-" ? [`old:${x.old}`] : x.kind === "+" ? [`new:${x.new}`] : [`new:${x.new}`, `old:${x.old}`]);
const anchorKey = (a) => (a.kind === "-" ? `old:${a.old}` : `new:${a.new}`);
const findingKey = (f) => `${f.side === "old" ? "old" : "new"}:${f.line}`;
// A finding's identity, stable across rewrites of the findings file.
const findingId = (f) => `${f.path}:${f.side}:${f.line}:${String(f.body).slice(0, 80)}`;

// The review pane: the branch's changes against its target (merge base to HEAD, what the
// request shows), files on the left and the diff on the right.
// Select a line (shift-click for a range) to comment on it or ask the agent beside it.
// The bar on top runs the review: Start review collects comments as pending, Submit posts
// them at once (with Approve); a single comment posts right away.
export class Review {
  constructor(view, cx) {
    this.view = view;
    this.r = props().redline;
    this.files = []; this.rows = []; this.open = null; this.sel = null;
    this.threads = []; this.drafts = []; this.reviewing = false;
    this.event = "COMMENT";
    this.full = false;          // whole file instead of hunks
    this.findings = [];         // the council's, from props.findings
    this.showFindings = false;
    this.replyTo = null; this.editing = null; this.fromFinding = null;
    this.box = TextareaState.new({ placeholder: "Comment, or a question for the agent…", rows: 3 });
    this.summary = TextareaState.new({ placeholder: "Review summary (optional)", rows: 3 });
    this.refresh(cx, true);
    if (this.r.number) this.loadRequest(cx);
    // Cheap check: reload when HEAD or the target moves (new commits, a rebase).
    cx.timer.every(5000, (cx) => this.refresh(cx, false));
    // The request itself, less often: a push by its author shows Update.
    if (this.r.number) cx.timer.every(60000, (cx) => this.pollRequest(cx));
  }

  get repo() { return { provider: this.r.provider, host: this.r.host, repo: this.r.repo, on: this.r.on }; }
  get mark() { return this.r.provider === "github" ? "#" : "!"; }
  get draftKey() { return `redline.drafts.${this.r.host}/${this.r.repo}${this.mark}${this.r.number}`; }
  git(args) { return git(this.r.folder, [...READ, ...args], this.r.on); }

  // ---- loading ----

  // Polled every few seconds: redraws only when something changed. Uncommitted edits (the
  // agent at work) only update the count; the diff, and the lines you selected, stay.
  refresh(cx, force) {
    if (this.loading) return;
    this.loading = true;
    cx.spawn(async (cx) => {
      let changed = false;
      try {
        if (await this.readFindings()) changed = true;
        const head = (await this.git(["rev-parse", "HEAD"])).out;
        // The request's diff is against the merge base with the target commit GitLab/GitHub used
        // (refs.start); line numbers on the old side only match against that one. Before the
        // request loads, or if that commit isn't here, the local origin/<target>.
        const start = this.refs?.start;
        if (start && this.startHere?.sha !== start) {
          this.startHere = { sha: start, ok: (await this.git(["cat-file", "-e", `${start}^{commit}`])).ok };
        }
        const base = (start && this.startHere?.ok && (await this.git(["merge-base", start, "HEAD"])).out)
          || (await this.git(["merge-base", `origin/${this.r.target}`, "HEAD"])).out
          || (await this.git(["merge-base", this.r.target, "HEAD"])).out;
        if (!base) throw new Error(`No common history with ${this.r.target}`);
        const dirty = (await this.git(["status", "--porcelain"])).out.split("\n").filter(Boolean).length;
        if (dirty !== this.dirty) { this.dirty = dirty; changed = true; }
        if (!force && head === this.head && base === this.base) return;
        changed = true;
        this.head = head; this.base = base;
        const stat = await this.git(["diff", "--numstat", "-z", "-M", base, head]);
        if (!stat.ok) throw new Error(stat.err);
        this.files = numstat(stat.out);
        if (!this.files.some((f) => f.path === this.open)) this.open = this.files[0]?.path ?? null;
        this.error = null;
        if (this.open) await this.load(this.open);
      } catch (e) {
        if (msg(e) !== this.error) { this.error = msg(e); changed = true; }
      } finally {
        this.loading = false;
        if (changed) cx.notify();
      }
    });
  }

  // The request's commits, comments and pending review comments.
  loadRequest(cx) {
    cx.spawn(async (cx) => {
      try {
        const [refs, d, drafts, st] = await Promise.all([
          host.refs(this.repo, this.r.number), host.detail(this.repo, this.r.number), host.listDrafts(this.repo, this.r.number),
          host.status(this.repo, this.r.number).catch(() => null),
        ]);
        this.mrStatus = st;
        const moved = this.refs?.start !== refs.start;
        this.refs = refs; this.threads = d.threads.filter((t) => t.inline); this.detail = d;
        if (moved) this.refresh(cx, true);
        this.drafts = drafts ? drafts.map((x) => ({ id: x.id, body: x.body, anchor: { path: x.path, kind: x.kind, old: x.old, new: x.new } }))
          : (shared(this.draftKey) ?? []);
        if (this.drafts.length) this.reviewing = true;
        this.requestError = null;
      } catch (e) { this.requestError = msg(e); }
      cx.notify();
    });
  }

  // ---- the council's findings ----

  get findingsKey() { return `redline.findings.${this.r.folder}`; }
  findingState(f) { return (shared(this.findingsKey) ?? {})[findingId(f)] ?? null; } // "accepted" | "dropped" | null
  setFindingState(f, state) { setShared(this.findingsKey, { ...(shared(this.findingsKey) ?? {}), [findingId(f)]: state }); }
  openFindings() { return this.findings.filter((f) => !this.findingState(f)); }

  // Reads the findings file when it changed; true if the list did.
  async readFindings() {
    if (!this.r.findings) return false;
    let text = null;
    try { text = await readTextFile(this.r.findings, { on: this.r.on }); } catch { text = null; }
    if (text === this.findingsText) return false;
    this.findingsText = text;
    try {
      const list = JSON.parse(text ?? "[]");
      this.findings = (Array.isArray(list) ? list : []).filter((f) => f && f.path && f.line && f.body)
        .map((f) => ({ path: String(f.path), line: Number(f.line), side: f.side === "old" ? "old" : "new", severity: f.severity ?? "", body: String(f.body) }));
      this.findingsError = null;
      if (this.openFindings().length) this.showFindings = true;
    } catch (e) { this.findingsError = `The findings file isn't valid JSON: ${msg(e)}`; }
    return true;
  }

  // The diff line a finding points at (it must be in the request's hunks), as an anchor.
  async anchorFor(f) {
    const file = this.file(f.path);
    if (!file) return null;
    const paths = file.oldPath ? [file.oldPath, f.path] : [f.path];
    const r = await this.git(["diff", "--no-ext-diff", "--no-color", "-M", "-U3", this.base, this.head, "--", ...paths]);
    const row = diffRows(r.out).find((x) => (f.side === "old" ? x.kind !== "+" && x.old === f.line : x.kind !== "-" && x.new === f.line));
    if (!row || row.kind === "@") return null;
    return { path: f.path, ...(file.oldPath ? { oldPath: file.oldPath } : {}), kind: row.kind, old: row.old ?? null, new: row.new ?? null };
  }

  acceptFinding(f, cx) {
    if (this.blocked()) { this.note = this.blocked(); cx.notify(); return; }
    this.act("Accept finding", async () => {
      const a = await this.anchorFor(f);
      if (!a) throw new Error(`${f.path}:${f.line} isn't a line of the diff: Open it and pick the line.`);
      const d = await host.addDraft(this.repo, this.r.number, this.refs, a, f.body);
      this.drafts = [...this.drafts, { id: d.id, local: d.local, body: f.body, anchor: a, head: this.refs.head }];
      this.reviewing = true; this.saveLocal(); this.setFindingState(f, "accepted");
    }, cx);
  }

  // Jumps to the finding's line with its text in the box, to edit before adding it.
  openFinding(f, cx) {
    cx.spawn(async (cx) => {
      if (this.open !== f.path) { this.open = f.path; this.rows = []; this.sel = null; await this.load(f.path); }
      const i = this.rows.findIndex((x) => (f.side === "old" ? x.kind !== "+" && x.old === f.line : x.kind !== "-" && x.new === f.line));
      if (i >= 0) { this.sel = { from: i, to: i }; this.box.set_value(f.body); this.fromFinding = f; this.replyTo = null; this.editing = null; this.box.focus(); }
      else this.note = `${f.path}:${f.line} isn't in this diff.`;
      cx.notify();
    });
  }

  // Sends the council brief to the agent in this tab (for a tab opened with another agent).
  runCouncil(cx) {
    const to = this.target();
    if (!to) { this.note = "No agent in this tab to run the council."; cx.notify(); return; }
    const what = this.r.number ? `${this.r.provider === "github" ? "pull" : "merge"} request ${this.mark}${this.r.number} (${this.r.title})` : `branch ${this.r.branch}`;
    this.act("Run council", async () => {
      const r = await hc(["send", to, councilTask({ target: this.r.target }, what, this.r.findings)]);
      if (r.code !== 0) throw new Error((r.stderr || r.stdout).trim());
    }, cx);
  }

  // ---- finishing ----

  // Removes this review's worktree (only one under ~/.herdr/worktrees) and closes the tab.
  // Asks first; asks again before throwing away uncommitted or unpushed work.
  finish(cx) {
    if (this.confirm !== "finish" && this.confirm !== "finish-force") { this.confirm = "finish"; cx.notify(); return; }
    const force = this.confirm === "finish-force";
    const ours = this.r.folder.includes("/.herdr/worktrees/");
    this.act("Finish review", async () => {
      if (ours) {
        const dirty = (await this.git(["status", "--porcelain"])).out.split("\n").filter(Boolean).length;
        const ahead = Number((await this.git(["rev-list", "--count", "@{upstream}..HEAD"])).out) || 0;
        if ((dirty || ahead) && !force) {
          this.confirm = "finish-force";
          this.finishWarning = [dirty && `${dirty} uncommitted change${dirty === 1 ? "" : "s"}`, ahead && `${ahead} unpushed commit${ahead === 1 ? "" : "s"}`].filter(Boolean).join(" and ");
          throw new Error(`this worktree has ${this.finishWarning}: click again to throw them away`);
        }
        const common = (await this.git(["rev-parse", "--path-format=absolute", "--git-common-dir"])).out;
        const main = common.endsWith("/.git") ? common.slice(0, -5) : common;
        const branch = (await this.git(["branch", "--show-current"])).out;
        const rm = await git(main, ["worktree", "remove", ...(force ? ["--force"] : []), this.r.folder], this.r.on);
        if (!rm.ok) throw new Error(gitError(rm.err));
        // A review/... branch is the review's own: drop it if it holds nothing unmerged.
        if (branch.startsWith("review/")) await git(main, ["branch", force ? "-D" : "-d", branch], this.r.on);
      }
      if (this.r.provider === "github") setShared(this.draftKey, null);
      setShared(this.findingsKey, null);
      run("tab.close", { id: this.r.tab, confirmed: true });
    }, cx, () => {}, () => {});
  }

  // A request's head on GitLab/GitHub, every minute: when it moves, reload it (Update appears).
  pollRequest(cx) {
    cx.spawn(async (cx) => {
      try {
        const [refs, st] = await Promise.all([host.refs(this.repo, this.r.number), host.status(this.repo, this.r.number).catch(() => null)]);
        if (st && st.ci !== this.mrStatus?.ci) { this.mrStatus = st; cx.notify(); }
        if (this.refs && refs.head !== this.refs.head) this.loadRequest(cx);
      } catch { /* offline: try again next minute */ }
    });
  }

  file(path) { return this.files.find((f) => f.path === path) ?? null; }

  async load(path) {
    // Three lines of context, as GitLab and GitHub show: a comment can only go on a line they show.
    const f = this.file(path);
    const paths = f?.oldPath ? [f.oldPath, path] : [path];
    const diff = (u) => this.git(["diff", "--no-ext-diff", "--no-color", "-M", `-U${u}`, this.base, this.head, "--", ...paths]);
    const r = await diff(this.full ? 1000000 : 3);
    if (this.open !== path) return;
    const rows = r.ok ? diffRows(r.out) : [];
    // In the full file, only lines GitLab/GitHub show (3 lines around a change) take comments on
    // GitHub; GitLab takes any line.
    this.commentable = null;
    if (this.full && r.ok) this.commentable = new Set(diffRows((await diff(3)).out).flatMap((x) => (x.kind === "@" ? [] : keysOf(x))));
    this.rows = rows.length ? rows.slice(0, 5000) : [{ kind: "@", text: r.ok ? "No text diff (binary or mode change)" : r.err }];
    this.width = Math.max(300, ...this.rows.map((x) => Math.min(x.text.length, 400) * 7 + 110));
    this.sel = null;
  }

  pick(path, cx) {
    if (this.open === path) return;
    this.open = path; this.rows = []; this.sel = null; cx.notify();
    cx.spawn(async (cx) => { try { await this.load(path); } catch (e) { this.error = msg(e); } cx.notify(); });
  }

  // Comments and pending comments on this file, by line key.
  marks() {
    const m = new Map();
    const add = (k, what) => { const v = m.get(k) ?? { threads: 0, drafts: 0, findings: 0 }; v[what]++; m.set(k, v); };
    for (const t of this.threads) if (t.path === this.open && t.line != null) add(`${t.side}:${t.line}`, "threads");
    for (const d of this.drafts) if (d.anchor.path === this.open) add(anchorKey(d.anchor), "drafts");
    for (const f of this.openFindings()) if (f.path === this.open) add(findingKey(f), "findings");
    return m;
  }

  // ---- selection ----

  select(i, shift, cx) {
    if (this.rows[i]?.kind !== "+" && this.rows[i]?.kind !== "-" && this.rows[i]?.kind !== " ") return;
    let sel = shift && this.sel ? { from: Math.min(this.sel.from, i), to: Math.max(this.sel.to, i) } : { from: i, to: i };
    // A range can't cross a hunk header: GitLab and GitHub only take lines of one hunk.
    if (this.rows.slice(sel.from, sel.to + 1).some((x) => x.kind === "@")) sel = { from: i, to: i };
    this.sel = sel;
    this.confirm = null; this.replyTo = null; this.editing = null; this.fromFinding = null;
    this.box.focus();
    cx.notify();
  }

  anchor() {
    if (!this.sel) return null;
    const last = this.rows[this.sel.to], first = this.rows[this.sel.from];
    if (!last || !first || last.kind === "@") return null;
    const oldPath = this.file(this.open)?.oldPath;
    const a = { path: this.open, ...(oldPath ? { oldPath } : {}), kind: last.kind, old: last.old ?? null, new: last.new ?? null };
    if (this.sel.from !== this.sel.to) a.start = { kind: first.kind, old: first.old ?? null, new: first.new ?? null };
    return a;
  }

  where() {
    const { from, to } = this.sel;
    const nums = this.rows.slice(from, to + 1).map((x) => x.new ?? x.old).filter((n) => n != null);
    return `${this.open}:${nums[0]}${nums.length > 1 && nums[nums.length - 1] !== nums[0] ? `–${nums[nums.length - 1]}` : ""}`;
  }

  // Why a comment can't be posted now, or null.
  blocked() {
    if (!this.r.number) return "A branch without a request: there's nowhere to post comments.";
    if (!this.refs) return this.requestError ? `Couldn't load the request: ${this.requestError}` : "Loading the request…";
    if (this.head && this.refs.head && this.head !== this.refs.head) return "This worktree isn't at the request's latest commit: Update first.";
    return null;
  }

  // Why the selected line can't take a comment, or null.
  lineBlocked() {
    const b = this.blocked();
    if (b) return b;
    const a = this.anchor();
    if (a && this.commentable && this.r.provider === "github" && !this.commentable.has(anchorKey(a))) {
      return "GitHub only takes comments on lines within 3 of a change.";
    }
    return null;
  }

  // ---- actions ----

  // Runs a GitLab/GitHub write with a busy label. `after(cx)` runs on success and `failed(cx)` on
  // failure, both with this task's cx: the caller's cx is stale once an await has passed.
  act(label, fn, cx, after = () => {}, failed = () => {}) {
    if (this.busy) return;
    this.busy = label; this.note = null; cx.notify();
    cx.spawn(async (cx) => {
      let ok = false;
      try { await fn(); ok = true; this.note = `${label}: done`; }
      catch (e) { this.note = `${label} failed: ${msg(e)}`; }
      // Kept apart from the write: a problem refreshing afterwards isn't a failed write.
      try { if (ok) after(cx); else failed(cx); } catch (e) { this.note = `${this.note} (refresh: ${msg(e)})`; }
      this.busy = null; cx.notify();
    });
  }

  saveLocal() { if (this.r.provider === "github") setShared(this.draftKey, this.drafts); }

  single(cx) {
    const body = this.box.value().trim(), a = this.anchor();
    if (!body || !a || this.lineBlocked()) return;
    this.act("Comment", () => host.lineComment(this.repo, this.r.number, this.refs, a, body), cx, (cx) => {
      this.box.set_value(""); this.sel = null; this.loadRequest(cx);
      if (this.fromFinding) { this.setFindingState(this.fromFinding, "accepted"); this.fromFinding = null; }
    });
  }

  addToReview(cx) {
    const body = this.box.value().trim(), a = this.anchor();
    if (!body || !a || this.lineBlocked()) return;
    this.act(this.reviewing ? "Add to review" : "Start review", async () => {
      const d = await host.addDraft(this.repo, this.r.number, this.refs, a, body);
      this.drafts = [...this.drafts, { id: d.id, local: d.local, body, anchor: a, head: this.refs.head }];
      this.reviewing = true; this.saveLocal();
    }, cx, () => {
      this.box.set_value(""); this.sel = null;
      if (this.fromFinding) { this.setFindingState(this.fromFinding, "accepted"); this.fromFinding = null; }
    });
  }

  replyThread(cx) {
    const body = this.box.value().trim(), th = this.replyTo;
    if (!body || !th) return;
    this.act("Reply", () => host.reply(this.repo, this.r.number, th, body), cx, (cx) => {
      this.box.set_value(""); this.replyTo = null; this.loadRequest(cx);
    });
  }

  resolveThread(th, cx) {
    this.act(th.resolved ? "Unresolve" : "Resolve", () => host.resolve(this.repo, this.r.number, th, !th.resolved), cx, (cx) => this.loadRequest(cx));
  }

  saveEdit(cx) {
    const body = this.box.value().trim(), d = this.editing;
    if (!body || !d) return;
    this.act("Edit pending comment", () => host.updateDraft(this.repo, this.r.number, d, body), cx, () => {
      this.drafts = this.drafts.map((x) => (x === d ? { ...x, body } : x)); this.saveLocal();
      this.box.set_value(""); this.editing = null;
    });
  }

  removeDraft(d, cx) {
    this.act("Remove pending comment", () => host.deleteDraft(this.repo, this.r.number, d), cx, () => {
      this.drafts = this.drafts.filter((x) => x !== d); this.saveLocal();
    });
  }

  discard(cx) {
    this.act("Discard review", async () => {
      for (const d of [...this.drafts]) {
        await host.deleteDraft(this.repo, this.r.number, d);
        this.drafts = this.drafts.filter((x) => x !== d); this.saveLocal();
      }
    }, cx, () => { this.reviewing = false; this.confirm = null; }, (cx) => this.loadRequest(cx));
  }

  // Why Submit can't go now, or null.
  cantSubmit() {
    const blocked = this.blocked();
    if (blocked) return blocked;
    const body = this.summary.value().trim();
    if (this.event === "REQUEST_CHANGES" && !body) return "Requesting changes needs a summary.";
    if (this.event === "COMMENT" && !this.drafts.length && !body) return "Nothing to submit yet: add a comment or a summary.";
    // GitHub's pending comments are line numbers of the version they were written on.
    if (this.drafts.some((d) => d.local && d.head && d.head !== this.refs.head)) {
      return "Some pending comments were written on an older version of the request: remove and redo them.";
    }
    return null;
  }

  submit(cx) {
    const why = this.cantSubmit();
    if (why) { this.note = why; cx.notify(); return; }
    const body = this.summary.value().trim(), event = this.event, drafts = this.drafts;
    this.menu = false;
    this.act("Submit review", () => host.submitReview(this.repo, this.r.number, this.refs, drafts, body, event), cx, (cx) => {
      this.drafts = []; this.reviewing = false; this.saveLocal(); this.summary.set_value(""); this.loadRequest(cx);
    }, (cx) => this.loadRequest(cx)); // GitLab may have published part: reload what's still pending
  }

  approve(cx) {
    const on = !this.detail?.approvedByMe;
    this.act(on ? "Approve" : "Withdraw approval", () => host.approve(this.repo, this.r.number, on), cx, (cx) => this.loadRequest(cx));
  }

  closeRequest(cx) {
    if (this.confirm !== "close") { this.confirm = "close"; cx.notify(); return; }
    this.confirm = null;
    this.act(`Close ${this.mark}${this.r.number}`, () => host.closeRequest(this.repo, this.r.number), cx);
  }

  update(cx) {
    const up = this.r.upstream;
    this.act("Update", async () => {
      const run = (args) => git(this.r.folder, args, this.r.on);
      if (!up) { // a tab opened before upstream was recorded
        const r = await run(["pull", "--ff-only", "--quiet"]);
        if (!r.ok) throw new Error(gitError(r.err));
        return;
      }
      const f = await run(["fetch", "--quiet", ...up.fetch]);
      if (!f.ok) throw new Error(gitError(f.err));
      const m = await run(["merge", "--ff-only", "--quiet", up.ref]);
      if (!m.ok) {
        throw new Error(`can't fast-forward to ${up.ref}: the request was rebased or force-pushed, or this worktree has commits of its own. `
          + `If it has nothing of yours, \`git reset --hard ${up.ref}\` in the review tab's terminal brings it in line.`);
      }
    }, cx, (cx) => { this.refresh(cx, true); this.loadRequest(cx); });
  }

  // The agent in this review's tab. Never a plain terminal: `hc send` presses Enter, and a
  // shell would run the pasted diff (backticks, $(...)) as commands.
  target() {
    return agents().find((x) => x.tab === this.r.tab)?.address ?? null;
  }

  ask(cx) {
    if (!this.sel || this.busy) return;
    const to = this.target();
    if (!to) { this.note = "No agent in this tab: start one in a pane here (claude, codex…), then Ask AI."; cx.notify(); return; }
    const body = this.rows.slice(this.sel.from, this.sel.to + 1).map((x) => `${x.kind}${x.text}`).join("\n");
    const what = this.r.number ? `request ${this.mark}${this.r.number} (${this.r.title})` : `branch ${this.r.branch}`;
    const q = this.box.value().trim() || "Explain this change and point out any problems.";
    const text = `Reviewing ${what}, ${this.r.branch} → ${this.r.target}. About ${this.where()} (diff, - removed / + added):\n\`\`\`diff\n${body}\n\`\`\`\n${q}`;
    this.act("Ask agent", async () => {
      const r = await hc(["send", to, text]);
      if (r.code !== 0) throw new Error((r.stderr || r.stdout).trim());
    }, cx, () => this.box.set_value(""));
  }

  openUrl() {
    if (this.r.url) exec("open", [this.r.url]).catch(() => exec("xdg-open", [this.r.url]).catch(() => {}));
  }

  // ---- drawing ----

  button(t, id, label, onClick, { primary = false, danger = false, disabled = false, tooltip = null } = {}) {
    return div().id(id).flex_none().h(26).px(10).flex().items_center().rounded(6).text_size(11.5)
      .when(primary, (e) => e.bg(disabled ? t.raised : t.solid).text_color(disabled ? t.dim : t.solid_foreground))
      .when(!primary, (e) => e.border_1().border_color(danger ? t.ansi1 : t.border).text_color(disabled ? t.dim : danger ? t.ansi1 : t.foreground))
      .when(!disabled, (e) => e.cursor_pointer().hover((s) => s.opacity(0.85)).on_click((_e, cx) => onClick(cx)))
      .when(Boolean(tooltip), (e) => e.tooltip(tooltip))
      .child(label);
  }

  // A line's text in colour (tokens cached on the row).
  code(x, t) {
    x.tokens ??= tokens(x.text, langOf(this.open));
    const color = { kw: t.ansi5, str: t.ansi2, num: t.ansi3, com: t.dim };
    return h_flex().flex_1().min_w(0).whitespace_nowrap()
      .children(x.tokens.map((k) => div().flex_none().whitespace_nowrap().when(Boolean(k.kind), (e) => e.text_color(color[k.kind])).child(k.text)));
  }

  row(x, i, t, marks) {
    const sel = this.sel && i >= this.sel.from && i <= this.sel.to;
    if (x.kind === "@") return div().w_full().h(ROW).flex_none().px(12).truncate().bg(t.raised).text_color(t.dim).child(x.text);
    const m = keysOf(x).map((k) => marks.get(k)).find(Boolean);
    const outside = this.commentable && !keysOf(x).some((k) => this.commentable.has(k));
    return h_flex().w_full().h(ROW).flex_none().cursor_pointer()
      .when(x.kind === "+", (e) => e.bg(t.ansi2 + "18")).when(x.kind === "-", (e) => e.bg(t.ansi1 + "18"))
      .when(sel, (e) => e.bg(t.selection))
      .hover((s) => s.bg(t.hover))
      .when(Boolean(outside), (e) => e.opacity(0.75))
      .child(div().w(18).flex_none().text_center().text_color(m?.drafts ? t.accent : m?.findings ? t.ansi5 : t.muted)
        .child(m ? (m.drafts ? "●" : m.threads ? "◆" : "✦") : ""))
      .child(div().w(40).flex_none().pr(6).text_right().text_color(t.dim).child(x.old == null ? "" : String(x.old)))
      .child(div().w(40).flex_none().pr(6).text_right().text_color(t.dim).child(x.new == null ? "" : String(x.new)))
      .child(div().w(14).flex_none().text_color(x.kind === "+" ? t.ansi2 : x.kind === "-" ? t.ansi1 : t.dim).child(x.kind === " " ? "" : x.kind))
      .child(this.code(x, t));
  }

  submitMenu(t) {
    const gh = this.r.provider === "github";
    const choices = [["COMMENT", "Comment", "General feedback"], ["APPROVE", "Approve", "Comments and your approval"]];
    if (gh) choices.push(["REQUEST_CHANGES", "Request changes", "Must be addressed before merging"]);
    const panel = v_flex().id("rv-submit-panel").w(360).p(12).gap(8).rounded(8).bg(t.popover).border_1().border_color(t.border).shadow_md()
      .child(div().text_size(12).font_semibold().child(`Submit review · ${this.drafts.length} pending`))
      .child(div().id("rv-summary").rounded(6).border_1().border_color(t.border).p(6).cursor_text()
        .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
        .child(Textarea.new(this.summary).w_full().text_size(12).text_color(t.foreground)))
      .children(choices.map(([k, label, hint]) => h_flex().id(`rv-ev-${k}`).gap(8).items_center().px(4).py(3).rounded(5).cursor_pointer()
        .hover((s) => s.bg(t.hover)).on_click((_e, cx) => { this.event = k; cx.notify(); })
        .child(div().size(12).flex_none().rounded(6).border_1().border_color(this.event === k ? t.accent : t.dim)
          .when(this.event === k, (e) => e.bg(t.accent)))
        .child(div().text_size(12).child(label))
        .child(div().text_size(10.5).text_color(t.dim).child(hint))))
      .when(Boolean(this.cantSubmit()), (e) => e.child(div().text_size(11).text_color(t.blocked).child(this.cantSubmit())))
      .child(h_flex().justify_end().child(this.button(t, "rv-submit-go", "Submit review", (cx) => this.submit(cx),
        { primary: true, disabled: Boolean(this.busy) || Boolean(this.cantSubmit()) })));
    return Popover.new("rv-submit").open(Boolean(this.menu))
      .on_open_change((o, cx) => { this.menu = o; cx.notify(); })
      .trigger(div().id("rv-submit-trigger").flex_none().h(26).px(10).flex().items_center().gap(6).rounded(6).text_size(11.5)
        .bg(t.solid).text_color(t.solid_foreground).cursor_pointer().child("Submit review ▾"))
      .content(panel);
  }

  reviewBar(t) {
    const r = this.r, d = this.detail;
    const approved = d?.approvedByMe;
    return h_flex().h(40).flex_none().px(12).gap(8).items_center().border_b(1).border_color(t.border).bg(t.chrome)
      .when(this.reviewing, (e) => e
        .child(div().flex_none().px(8).py(2).rounded(10).bg(t.accent + "30").text_size(11).text_color(t.accent)
          .child(`Reviewing · ${this.drafts.length} pending`))
        .child(this.submitMenu(t))
        .child(this.button(t, "rv-discard", this.confirm === "discard" ? "Discard all pending?" : "Discard",
          (cx) => { if (this.confirm === "discard") this.discard(cx); else { this.confirm = "discard"; cx.notify(); } },
          { danger: this.confirm === "discard", disabled: Boolean(this.busy) })))
      .when(!this.reviewing, (e) => e
        .child(this.button(t, "rv-start-review", "Start review", (cx) => { this.reviewing = true; cx.notify(); },
          { primary: true, tooltip: "Collect line comments as pending and post them together" }))
        .child(this.button(t, "rv-approve", this.busy === "Approve" ? "Approving…" : approved ? "✓ Approved" : "Approve", (cx) => this.approve(cx),
          { disabled: Boolean(this.busy) || !d || (!approved && !d.canApprove) || (approved && r.provider === "github"),
            tooltip: approved ? (r.provider === "github" ? "Dismiss an approval on GitHub's website" : "Click to withdraw your approval") : null })))
      .child(div().flex_1().min_w(0).truncate().text_size(11).text_color(t.dim)
        .child(this.busy ? `${this.busy}…` : d?.approvedBy?.length ? `Approved by ${d.approvedBy.join(", ")}` : ""))
      .when(Boolean(this.refs && this.head && this.refs.head !== this.head), (e) => e.child(this.button(t, "rv-update", "Update",
        (cx) => this.update(cx), { tooltip: "Pull the request's latest commits into this worktree" })))
      .when(Boolean(this.mrStatus?.ci), (e) => {
        const [icon, color] = JOB_LOOK[this.mrStatus.ci] ?? ["?", "dim"];
        return e.child(h_flex().id("rv-ci").flex_none().h(26).px(8).gap(5).items_center().rounded(6).border_1().border_color(t.border)
          .text_size(11.5).cursor_pointer().hover((s) => s.bg(t.hover)).tooltip("Pipeline: open Redline's Pipeline tab (cmd-shift-f)")
          .on_click(() => run("mod.open", { name: "redline" }))
          .child(div().text_color(t[color]).child(icon)).child(div().text_color(t.muted).child(`Pipeline ${this.mrStatus.ci}`)));
      })
      .child(this.aiButtons(t))
      .child(this.finishButton(t))
      .child(this.button(t, "rv-close-req", this.confirm === "close" ? `Close ${this.mark}${r.number}? Confirm` : "Close",
        (cx) => this.closeRequest(cx), { danger: true, disabled: Boolean(this.busy), tooltip: "Close the request without merging" }));
  }

  aiButtons(t) {
    const open = this.openFindings().length;
    return h_flex().flex_none().gap(8)
      .when(this.findings.length > 0, (e) => e.child(this.button(t, "rv-ai", `✦ AI ${open}`, (cx) => { this.showFindings = !this.showFindings; cx.notify(); },
        { tooltip: "The council's findings: accept them as pending comments, edit or drop" })))
      .when(Boolean(this.r.findings) && Boolean(this.target()), (e) => e.child(this.button(t, "rv-council", this.busy === "Run council" ? "Sending…" : "Run council",
        (cx) => this.runCouncil(cx), { disabled: Boolean(this.busy), tooltip: "Ask the agent here to run /council; its findings show up as ✦" })));
  }

  finishButton(t) {
    const label = this.confirm === "finish-force" ? `Discard ${this.finishWarning ?? "local work"} and finish?`
      : this.confirm === "finish" ? (this.drafts.length ? `Finish? ${this.drafts.length} pending stay unsubmitted` : "Finish: remove worktree & close?") : "Finish";
    return this.button(t, "rv-finish", label, (cx) => this.finish(cx), {
      danger: Boolean(this.confirm?.startsWith("finish")), disabled: Boolean(this.busy),
      tooltip: this.r.folder.includes("/.herdr/worktrees/") ? "Remove this review's worktree and close the tab" : "Close the review tab (this folder isn't a review worktree, so it stays)",
    });
  }

  // The council's findings, open ones first: Accept (pending comment), Open (edit first), Drop.
  findingsPanel(t) {
    const list = [...this.findings].sort((a, b) => Number(Boolean(this.findingState(a))) - Number(Boolean(this.findingState(b))));
    const sev = { blocker: t.ansi1, major: t.blocked, minor: t.muted, nit: t.dim };
    return v_flex().id("rv-findings").flex_none().max_h(300).overflow_y_scrollbar().border_t(1).border_color(t.border).bg(t.surface)
      .child(h_flex().px(12).py(6).gap(8).items_center()
        .child(div().flex_1().text_size(11.5).font_semibold().text_color(t.ansi5).child(`✦ Council findings · ${this.openFindings().length} open of ${this.findings.length}`))
        .child(div().id("rv-findings-x").text_size(11).text_color(t.dim).cursor_pointer().on_click((_e, cx) => { this.showFindings = false; cx.notify(); }).child("Hide")))
      .when(Boolean(this.findingsError), (e) => e.child(div().px(12).pb(4).text_size(11).text_color(t.ansi1).child(this.findingsError)))
      .children(list.map((f, i) => {
        const state = this.findingState(f);
        return v_flex().px(12).py(6).gap(3).border_t(1).border_color(t.border).when(Boolean(state), (e) => e.opacity(0.5))
          .child(h_flex().gap(8).items_center().text_size(11)
            .when(Boolean(f.severity), (e) => e.child(div().px(5).rounded(4).border_1().border_color(sev[f.severity] ?? t.border).text_color(sev[f.severity] ?? t.muted).child(f.severity)))
            .child(div().id(`rv-fi-loc-${i}`).flex_1().min_w(0).truncate().text_color(t.accent).cursor_pointer().on_click((_e, cx) => this.openFinding(f, cx))
              .child(`${f.path}:${f.line}${f.side === "old" ? " (old)" : ""}`))
            .when(Boolean(state), (e) => e.child(div().text_color(t.dim).child(state)))
            .when(!state, (e) => e
              .child(this.button(t, `rv-fi-open-${i}`, "Open", (cx) => this.openFinding(f, cx), { tooltip: "Go to the line with this text in the box, to edit first" }))
              .child(this.button(t, `rv-fi-acc-${i}`, "Accept", (cx) => this.acceptFinding(f, cx), { primary: true, disabled: Boolean(this.busy) || !this.r.number, tooltip: "Add as a pending review comment" }))
              .child(this.button(t, `rv-fi-drop-${i}`, "Drop", (cx) => { this.setFindingState(f, "dropped"); cx.notify(); }))))
          .child(div().text_size(11.5).child(TextView.markdown(`rv-fi-${findingId(f)}`, f.body)));
      }));
  }

  // Under the diff while lines are selected: what's already said there, then the comment box.
  composer(t) {
    if (!this.sel) {
      return div().flex_none().px(12).py(8).border_t(1).border_color(t.border).text_size(11).text_color(t.dim)
        .child("Click a line (shift-click for a range) to comment or ask the agent.");
    }
    const a = this.anchor();
    if (!a) {
      return div().flex_none().px(12).py(8).border_t(1).border_color(t.border).text_size(11).text_color(t.dim)
        .child("Click a line (shift-click for a range) to comment or ask the agent.");
    }
    const key = anchorKey(a);
    const lastLine = a.kind === "-" ? a.old : a.new;
    const here = this.threads.filter((th) => th.path === this.open && `${th.side}:${th.line}` === key);
    const pending = this.drafts.filter((d) => d.anchor.path === this.open && anchorKey(d.anchor) === key);
    const blocked = this.lineBlocked(), canPost = !blocked && !this.busy;
    return v_flex().flex_none().max_h(360).border_t(1).border_color(t.border).bg(t.surface)
      .child(h_flex().px(12).pt(8).gap(8).items_center()
        .child(div().flex_1().min_w(0).truncate().text_size(11.5).text_color(t.accent).child(this.where()))
        .child(div().id("rv-sel-x").text_size(11).text_color(t.dim).cursor_pointer().on_click((_e, cx) => { this.sel = null; cx.notify(); }).child("Esc ✕")))
      .when(here.length + pending.length > 0, (e) => e.child(v_flex().id("rv-here").max_h(160).overflow_y_scrollbar().px(12).pt(6).gap(6)
        .children(here.map((th, i) => v_flex().gap(4).p(6).rounded(6).border_1().border_color(this.replyTo === th ? t.accent : t.border)
          .children(th.notes.map((n, k) => v_flex().gap(2)
            .child(h_flex().gap(6).text_size(10.5).child(div().font_semibold().child(n.author)).child(div().text_color(t.dim).child(ago(n.at))))
            .child(div().text_size(11.5).child(TextView.markdown(`rv-h-${th.id}-${k}`, n.body || " ")))))
          .child(h_flex().gap(12).text_size(11)
            .child(div().id(`rv-th-reply-${i}`).text_color(t.accent).cursor_pointer()
              .on_click((_e, cx) => { this.replyTo = this.replyTo === th ? null : th; this.editing = null; this.box.focus(); cx.notify(); })
              .child(this.replyTo === th ? "Cancel reply" : "Reply"))
            .when(th.resolvable, (e) => e.child(div().id(`rv-th-res-${i}`).text_color(t.muted).cursor_pointer()
              .on_click((_e, cx) => this.resolveThread(th, cx)).child(th.resolved ? "Unresolve" : "Resolve")))
            .when(th.resolvable && th.resolved, (e) => e.child(div().text_color(t.ansi2).child("resolved"))))))
        .children(pending.map((d, i) => h_flex().gap(6).items_start()
          .child(div().flex_none().text_size(10.5).px(5).rounded(4).bg(t.accent + "30").text_color(t.accent).child(this.editing === d ? "editing" : "pending"))
          .child(div().flex_1().min_w(0).text_size(11.5).child(d.body))
          .child(div().id(`rv-ed-${i}`).flex_none().text_size(11).text_color(t.accent).cursor_pointer()
            .on_click((_e, cx) => { this.editing = d; this.replyTo = null; this.box.set_value(d.body); this.box.focus(); cx.notify(); }).child("Edit"))
          .child(div().id(`rv-rm-${i}`).flex_none().text_size(11).text_color(t.dim).cursor_pointer().on_click((_e, cx) => this.removeDraft(d, cx)).child("✕"))))))
      .child(div().px(12).pt(6).child(div().id("rv-box").rounded(6).border_1().border_color(t.accent).p(6).cursor_text()
        .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
        .child(Textarea.new(this.box).w_full().text_size(12).text_color(t.foreground))))
      .when(Boolean(blocked) && Boolean(this.r.number), (e) => e.child(div().px(12).pt(4).text_size(11).text_color(t.blocked).child(blocked)))
      .when(Boolean(a.start) && this.r.provider === "gitlab" && Boolean(this.r.number), (e) => e.child(div().px(12).pt(4).text_size(11).text_color(t.dim)
        .child(`GitLab comments go on one line: this one is posted on line ${lastLine}. Ask AI gets the whole range.`)))
      .child(h_flex().px(12).py(8).gap(8).items_center()
        .child(this.button(t, "rv-ask", "Ask AI", (cx) => this.ask(cx), { disabled: Boolean(this.busy), tooltip: "Send these lines and your text to the agent beside the diff" }))
        .child(div().flex_1())
        .when(Boolean(this.r.number) && Boolean(this.replyTo), (e) => e
          .child(this.button(t, "rv-reply-go", "Reply", (cx) => this.replyThread(cx), { primary: true, disabled: Boolean(this.busy), tooltip: "Post a reply in this thread now" })))
        .when(Boolean(this.r.number) && Boolean(this.editing), (e) => e
          .child(this.button(t, "rv-edit-x", "Cancel", (cx) => { this.editing = null; this.box.set_value(""); cx.notify(); }))
          .child(this.button(t, "rv-edit-go", "Save pending comment", (cx) => this.saveEdit(cx), { primary: true, disabled: Boolean(this.busy) })))
        .when(Boolean(this.r.number) && !this.replyTo && !this.editing, (e) => e
          .child(this.button(t, "rv-single", "Add single comment", (cx) => this.single(cx), { disabled: !canPost, tooltip: "Post now" }))
          .child(this.button(t, "rv-draft", this.reviewing ? "Add review comment" : "Start a review", (cx) => this.addToReview(cx),
            { primary: true, disabled: !canPost, tooltip: "Pending until you submit the review" }))));
  }

  render() {
    const t = theme(), r = this.r, marks = this.marks();
    const add = this.files.reduce((n, f) => n + f.add, 0), del = this.files.reduce((n, f) => n + f.del, 0);
    const label = r.number ? `${this.mark}${r.number}` : "branch";
    const draftFiles = new Map();
    for (const d of this.drafts) draftFiles.set(d.anchor.path, (draftFiles.get(d.anchor.path) ?? 0) + 1);
    const threadFiles = new Map();
    for (const th of this.threads) threadFiles.set(th.path, (threadFiles.get(th.path) ?? 0) + 1);

    const header = h_flex().h(40).flex_none().px(14).gap(10).items_center().border_b(1).border_color(t.border)
      .child(div().flex_none().text_color(t.accent).text_size(12).child(label))
      .child(div().flex_1().min_w(0).truncate().font_semibold().child(r.title ?? r.branch))
      .child(div().flex_none().max_w(260).truncate().text_size(11).text_color(t.dim).child(`${r.branch} → ${r.target}`))
      .child(div().flex_none().text_size(11).text_color(t.ansi2).child(`+${add}`))
      .child(div().flex_none().text_size(11).text_color(t.ansi1).child(`−${del}`))
      .when(Boolean(r.url), (e) => e.child(this.button(t, "rv-web", "Open ↗", () => this.openUrl())));

    const files = v_flex().id("rv-files").w(240).h_full().flex_none().min_h(0).overflow_y_scrollbar().p(6).gap(1).border_r(1).border_color(t.border)
      .children(this.files.map((f) => {
        const name = f.path.split("/").pop(), nd = draftFiles.get(f.path), nt = threadFiles.get(f.path);
        return h_flex().id(`rv-f-${f.path}`).h(26).flex_none().px(8).gap(6).items_center().rounded(6).cursor_pointer()
          .when(this.open === f.path, (e) => e.bg(t.selected)).hover((s) => s.bg(t.hover))
          .on_click((_e, cx) => this.pick(f.path, cx)).tooltip(f.path)
          .child(div().flex_1().min_w(0).truncate().text_size(12).child(name))
          .when(Boolean(nd), (e) => e.child(div().text_size(10.5).text_color(t.accent).child(`●${nd}`)))
          .when(Boolean(nt), (e) => e.child(div().text_size(10.5).text_color(t.muted).child(`◆${nt}`)))
          .when(f.add > 0, (e) => e.child(div().text_size(10.5).text_color(t.ansi2).child(`+${f.add}`)))
          .when(f.del > 0, (e) => e.child(div().text_size(10.5).text_color(t.ansi1).child(`−${f.del}`)));
      }))
      .when(!this.files.length, (e) => e.child(div().p(8).text_size(12).text_color(t.dim)
        .child(this.error ?? (this.loading ? "Loading…" : "No changes against the target"))));

    const diff = v_flex().flex_1().h_full().min_w(0).min_h(0)
      .child(h_flex().h(28).flex_none().px(12).gap(8).items_center().border_b(1).border_color(t.border).text_size(11.5).text_color(t.muted)
        .child(div().flex_1().min_w(0).truncate().child(this.file(this.open)?.oldPath ? `${this.file(this.open).oldPath} → ${this.open}` : (this.open ?? "")))
        .child(div().id("rv-full").flex_none().px(8).py(1).rounded(5).border_1().border_color(this.full ? t.accent : t.border)
          .text_color(this.full ? t.accent : t.muted).cursor_pointer().tooltip("Show the whole file around the changes")
          .on_click((_e, cx) => {
            this.full = !this.full; this.sel = null;
            const path = this.open;
            if (path) cx.spawn(async (cx) => { try { await this.load(path); } catch (e) { this.error = msg(e); } cx.notify(); });
            cx.notify();
          })
          .child(this.full ? "✓ Full file" : "Full file")))
      .child(div().flex_1().min_h(0).relative().font_family(settings().font_family ?? "JetBrains Mono").text_size(11.5)
        .child(div().id("rv-diff-x").size_full().overflow_x_scrollbar()
          .child(div().w_full().min_w(this.width ?? 300).h_full()
            .child(v_virtual_list("rv-diff", this.rows.length, ROW, (i) => String(i),
              (range) => this.rows.slice(range.start, range.end).map((x, k) => this.row(x, range.start + k, t, marks)))
              .on_item_click((key, cx) => this.select(Number(key), this.shift, cx)).size_full())))
        .child(Scrollbar.vertical("rv-diff").viewport_from_layout().absolute().inset_0()))
      .when(this.showFindings && this.findings.length > 0, (e) => e.child(this.findingsPanel(t)))
      .child(this.composer(t));

    return v_flex().id("review").size_full().min_h(0).bg(t.background).text_color(t.foreground).text_size(13)
      .track_focus(this.view.handle)
      .on_modifiers_changed((e) => { this.shift = e.modifiers.shift; })
      .on_key_down((e, cx) => {
        if (e.key === "escape" && (this.sel || this.confirm || this.replyTo || this.editing)) {
          this.sel = null; this.confirm = null; this.replyTo = null; this.editing = null;
          this.view.handle.focus(); cx.stop_propagation(); cx.notify();
        }
      })
      .child(header)
      .when(Boolean(this.r.number), (e) => e.child(this.reviewBar(t)))
      .when(!this.r.number, (e) => e.child(h_flex().h(40).flex_none().px(12).gap(8).items_center().border_b(1).border_color(t.border).bg(t.chrome)
        .child(div().flex_1().text_size(11).text_color(t.dim).child(this.busy ? `${this.busy}…` : "Branch review: nothing is posted anywhere"))
        .child(this.aiButtons(t)).child(this.finishButton(t))))
      .when(this.dirty > 0, (e) => e.child(div().px(14).py(3).text_size(11).text_color(t.blocked).bg(t.raised)
        .child(`${this.dirty} uncommitted change${this.dirty === 1 ? "" : "s"} in the worktree (not shown: the review is of commits)`)))
      .when(Boolean(this.error) && this.files.length > 0, (e) => e.child(div().px(14).py(3).text_size(11).text_color(t.ansi1).child(this.error)))
      .when(Boolean(this.note), (e) => e.child(div().px(14).py(3).text_size(11).text_color(/failed/.test(this.note) ? t.ansi1 : t.muted).child(this.note)))
      .child(h_flex().flex_1().min_h(0).items_start().child(files).child(diff));
  }
}
