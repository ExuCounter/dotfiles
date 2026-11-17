import { div } from "gpui-kit";
import { v_flex, h_flex, InputState, Input, TextareaState, Textarea, TextView, Popover } from "gpui-base";
import {
  exec, focused, spaces, panes, theme, props, run, closeOverlay, openOverlay, knownAgents, home, shared, setShared, notify, agents, hc,
} from "herdr";
import { repoAt, listRequests, listBranches, checkout, git, msg } from "./lib.js";
import * as host from "./hosting.js";
import { logo } from "./logo.js";
import { overview, pipelineView, JOB_LOOK } from "./panels.js";
import { WATCH, HEARTBEAT } from "./watch.js";

const AGENT_KEY = "redline.agent"; // shared: the option id last picked

// What a review tab can open beside the diff: an agent to talk to, an agent started on an
// automated review (a Claude skill as its first message), or a plain shell.
function reviewOptions(agents) {
  const opts = agents.map((a) => ({ id: a.key, group: "Discuss with an agent", label: a.name, argv: a.run }));
  const claude = agents.find((a) => a.key === "claude");
  if (claude) {
    opts.push({ id: "council", group: "Automated review", label: "Council review", hint: "Claude + GPT + Grok, findings checked",
      argv: claude.run, task: councilTask });
  }
  opts.push({ id: "shell", group: "Other", label: "Shell only", hint: "no agent", argv: undefined });
  return opts;
}
// The council's brief. Its confirmed findings go to `findings` as JSON, where the review pane
// picks them up as AI suggestions you accept (as pending comments), edit or drop.
export function councilTask(row, what, findings) {
  return `/council Review ${what}: the diff \`git diff origin/${row.target}...HEAD\`. `
    + `When you're done, write every confirmed finding to ${findings} as a JSON array (overwrite the file), one object per finding: `
    + `{"path": "<file, relative to the repo root>", "line": <line number>, "side": "new" or "old" (old only for a removed line), `
    + `"severity": "blocker" | "major" | "minor" | "nit", "body": "<the review comment to post, in markdown>"}. `
    + `Use only lines that are part of the diff. Also summarise the findings here.`;
}

const ago = (t) => {
  const s = (Date.now() - t) / 1000;
  return !t ? "" : s < 3600 ? `${Math.max(1, Math.round(s / 60))}m` : s < 86400 ? `${Math.round(s / 3600)}h` : `${Math.round(s / 86400)}d`;
};

// Where the keyboard is: the focused terminal's folder, on its space's machine.
function here() {
  const f = focused();
  if (!f) return null;
  const sp = spaces().find((s) => s.id === f.space);
  const inTab = panes().filter((p) => p.tab === f.tab && p.cwd);
  const cwd = f.cwd ?? inTab.find((p) => p.focused)?.cwd ?? inTab[0]?.cwd ?? sp?.folder;
  return cwd ? { cwd, on: sp?.machine ?? null } : null;
}

const tabIds = () => new Set(spaces().flatMap((s) => (s.tabs ?? []).map((t) => t.id)));
const pause = (ms) => exec("sleep", [String(ms / 1000)]);
const keyOf = (x) => (x ? (x.kind === "request" ? `r${x.number}` : `b${x.branch}`) : null);

// The dashboard: cmd-shift-f. Open requests (and branches without one) on the left; the
// selected one's approvals, comments and commits on the right. Approve, reply, or Start
// review: check it out in a worktree and open a tab with the agent beside the diff.
export class Launcher {
  constructor(view, cx) {
    this.view = view;
    this.filter = ""; this.at = 0; this.requests = []; this.branches = []; this.options = [];
    this.details = new Map(); this.tab = "overview"; this.replyTo = null;
    this.status2 = { me: "", byNumber: {} }; // list extras: pipeline, threads, reviewers, blockers
    this.filterMode = null;                  // null | "waiting" (on me) | "mine"
    this.mrStatus = new Map(); this.pipes = new Map(); this.opts = new Map(); // per request number
    this.adding = null;                      // { what, row, list }: the + add input is open
    this.peopleInput = InputState.new({ placeholder: "name, Enter to add" });
    this.peopleInput.on("submit", (_e, cx) => this.addPerson(cx));
    this.peopleInput.on("focus", (_e, cx) => { this.typing = true; cx.notify(); });
    this.peopleInput.on("blur", (_e, cx) => { this.typing = false; cx.notify(); });
    // A running pipeline on screen refreshes itself.
    cx.timer.every(15000, (cx) => {
      const row = this.current(), p = row && this.pipes.get(row.number);
      if (this.tab === "pipeline" && p && (p.status === "running" || p.status === "pending")) this.loadPipeline(row, cx, true);
    });
    this.status = "Finding the repository…";
    this.input = InputState.new({ placeholder: "Filter requests and branches…" });
    this.input.on("change", (_e, cx) => { this.filter = this.input.value(); this.at = 0; this.select(cx); });
    this.input.on("submit", (_e, cx) => this.start(this.current(), cx));
    this.replyBox = TextareaState.new({ placeholder: "Reply…", rows: 3 });
    this.commentBox = TextareaState.new({ placeholder: "Comment on the request…", rows: 3 });
    for (const box of [this.replyBox, this.commentBox]) {
      box.on("focus", (_e, cx) => { this.typing = true; cx.notify(); });
      box.on("blur", (_e, cx) => { this.typing = false; cx.notify(); });
    }
    this.input.focus();
    cx.timer.after(300, () => this.input.focus());
    this.load(cx);
  }

  close() { closeOverlay(props().overlay); }

  load(cx) {
    const where = here();
    if (!where) { this.status = "Focus a terminal inside a git repository first."; return; }
    cx.spawn(async (cx) => {
      try {
        this.repo = this.repo ?? await repoAt(where.cwd, where.on);
        // Notifications are off until they run somewhere that can't block clicks (see watch.js).
        this.status = "Loading…"; cx.notify();
        const [agents, branches] = await Promise.all([
          knownAgents({ on: this.repo.on }).then((l) => l.filter((a) => a.agent && a.installed)).catch(() => []),
          listBranches(this.repo),
        ]);
        this.options = reviewOptions(agents);
        if (!this.options.some((o) => o.id === this.choice)) this.choice = shared(AGENT_KEY);
        if (!this.options.some((o) => o.id === this.choice)) this.choice = this.options[0].id;
        this.branches = branches;
        this.requestError = null;
        if (this.repo.provider) {
          try { this.requests = await listRequests(this.repo); }
          catch (e) { this.requestError = msg(e); }
        } else this.requestError = "No origin remote: showing branches only.";
        this.status = null;
        this.select(cx);
        if (this.repo.provider) {
          cx.notify();
          // Pipeline, unresolved threads, reviewers: nice to have, so a failure only hides them.
          try { this.status2 = await host.listStatus(this.repo); } catch { /* shown without them */ }
        }
      } catch (e) { this.status = msg(e); }
      cx.notify();
    });
  }

  // A request asks me to review and I haven't approved it yet.
  waitingOnMe(r) {
    const st = this.status2.byNumber[r.number], me = this.status2.me;
    return Boolean(st && me && st.reviewers.includes(me) && !st.approvedBy.includes(me));
  }

  // Notifications: remember this repo for the watcher, and open the watcher if it's quiet.
  watch(repo) {
    const me = { provider: repo.provider, host: repo.host, repo: repo.repo, on: repo.on };
    const list = (shared(WATCH) ?? []).filter((r) => !(r.host === me.host && r.repo === me.repo));
    if (!(shared(WATCH) ?? []).some((r) => r.host === me.host && r.repo === me.repo)) setShared(WATCH, [me, ...list].slice(0, 5));
    const beat = shared(HEARTBEAT);
    if (!beat || Date.now() - beat > 5 * 60000) {
      openOverlay({ mod: "redline", props: { watch: true }, kind: "window", key: "redline-watch", keep: true, width: 1, height: 1, frame: "none", at: { x: 0, y: 0 } });
      setShared(HEARTBEAT, Date.now());
    }
  }

  rows() {
    const f = this.filter.toLowerCase();
    const has = (s) => !f || s.toLowerCase().includes(f);
    const reqBranches = new Set(this.requests.map((r) => r.branch));
    const keep = (r) => (this.filterMode === "waiting" ? this.waitingOnMe(r) : this.filterMode === "mine" ? r.author === this.status2.me : true);
    const reqs = this.requests.filter((r) => has(`${r.number} ${r.title} ${r.branch} ${r.author}`) && keep(r))
      .map((r) => ({ kind: "request", ...r }));
    if (this.filterMode) return reqs;
    const branches = this.branches
      .filter((b) => !reqBranches.has(b.branch) && b.branch !== this.repo?.defaultBranch && has(b.branch))
      .slice(0, 30).map((b) => ({ kind: "branch", ...b, target: this.repo?.defaultBranch }));
    return [...reqs, ...branches];
  }

  current() { return this.rows()[this.at] ?? null; }
  option() { return this.options.find((o) => o.id === this.choice) ?? null; }
  mark() { return this.repo?.provider === "github" ? "#" : "!"; }

  choose(id, cx) {
    this.choice = id; this.menu = false;
    setShared(AGENT_KEY, id);
    cx.notify();
  }

  cycle(step, cx) {
    const n = this.options.length;
    if (!n) return;
    const i = Math.max(0, this.options.findIndex((o) => o.id === this.choice));
    this.choose(this.options[(i + step + n) % n].id, cx);
  }

  // Loads a row's details (the selected one by default) once; again with force, after an action.
  select(cx, force = false, row = this.current()) {
    if (row?.kind === "request") {
      this.loadStatus(row, cx, force);
      if (this.tab === "pipeline" || force) this.loadPipeline(row, cx, force && this.pipes.has(row.number));
    }
    const key = keyOf(row);
    if (!row || (!force && this.details.has(key))) { cx.notify(); return; }
    if (!force) this.details.set(key, { loading: true });
    if (row === this.current()) this.replyTo = null;
    cx.spawn(async (cx) => {
      try {
        const d = row.kind === "request"
          ? await host.detail(this.repo, row.number)
          : { commits: await host.branchCommits((a) => git(this.repo.main, a, this.repo.on), row.target, row.branch), threads: [], description: "" };
        this.details.set(key, d);
      } catch (e) { this.details.set(key, { error: msg(e) }); }
      cx.notify();
    });
    cx.notify();
  }

  move(step, cx) {
    const n = this.rows().length;
    if (!n) return;
    this.at = (this.at + step + n) % n;
    this.select(cx);
  }

  // Runs a GitLab/GitHub write, then reloads the details of the row it was for (even if another
  // row is selected by then).
  act(label, fn, cx, after = () => {}) {
    if (this.busyAct) return;
    const row = this.current();
    this.busyAct = label; this.error = null; cx.notify();
    cx.spawn(async (cx) => {
      try {
        await fn(); after(); this.select(cx, true, row);
        if (this.pendingTask) { const task = this.pendingTask; this.pendingTask = null; this.busyAct = null; this.start(row, cx, task); }
      }
      catch (e) { this.error = `${label} failed: ${msg(e)}`; }
      finally { this.busyAct = null; cx.notify(); }
    });
  }

  approve(row, d, cx) {
    const on = !d.approvedByMe;
    this.act(on ? "Approve" : "Unapprove", () => host.approve(this.repo, row.number, on), cx);
  }

  sendReply(row, thread, cx) {
    const body = this.replyBox.value().trim();
    if (!body) return;
    this.act("Reply", () => host.reply(this.repo, row.number, thread, body), cx, () => { this.replyBox.set_value(""); this.replyTo = null; });
  }

  sendComment(row, cx) {
    const body = this.commentBox.value().trim();
    if (!body) return;
    this.act("Comment", () => host.comment(this.repo, row.number, body), cx, () => this.commentBox.set_value(""));
  }

  // ---- Overview and Pipeline data ----

  loadStatus(row, cx, force = false) {
    if (!force && this.mrStatus.has(row.number)) return;
    if (!this.mrStatus.has(row.number)) this.mrStatus.set(row.number, { loading: true });
    cx.spawn(async (cx) => {
      try { this.mrStatus.set(row.number, await host.status(this.repo, row.number)); }
      catch (e) { this.mrStatus.set(row.number, { error: msg(e) }); }
      cx.notify();
    });
  }

  loadPipeline(row, cx, force = false) {
    if (!force && this.pipes.has(row.number)) return;
    if (!this.pipes.has(row.number)) this.pipes.set(row.number, { loading: true });
    cx.spawn(async (cx) => {
      try { this.pipes.set(row.number, (await host.pipeline(this.repo, row.number)) ?? { none: true }); }
      catch (e) { this.pipes.set(row.number, { error: msg(e) }); }
      cx.notify();
    });
  }

  // Merge options for a request: the request's own defaults until you change them.
  mergeOpts(n, s) {
    if (!this.opts.has(n)) this.opts.set(n, { squash: s.squash, removeBranch: s.removeBranch, auto: false });
    return this.opts.get(n);
  }
  setMergeOpt(n, k, v, cx) { this.opts.set(n, { ...this.opts.get(n), [k]: v }); cx.notify(); }

  merge(row, o, cx) {
    const key = `merge-${row.number}`;
    if (this.confirm !== key) { this.confirm = key; cx.notify(); return; }
    this.confirm = null;
    this.act(o.auto ? "Set auto-merge" : "Merge", () => host.merge(this.repo, row.number, o), cx);
  }

  cancelAuto(row, cx) { this.act("Cancel auto-merge", () => host.cancelAutoMerge(this.repo, row.number), cx); }

  toggleDraft(row, s, cx) {
    this.act(s.draft ? "Mark as ready" : "Mark as draft", () => host.setDraft(this.repo, row.number, s.title, !s.draft), cx);
  }

  startAdding(row, what, list, cx) {
    this.adding = { row, what, list };
    this.peopleInput.set_value("");
    this.peopleInput.focus();
    cx.notify();
  }

  addPerson(cx) {
    const a = this.adding, names = this.peopleInput.value().split(/[,\s]+/).map((x) => x.trim()).filter(Boolean);
    if (!a || !names.length) { this.adding = null; cx.notify(); return; }
    this.adding = null;
    this.act(`Add ${a.what}`, () => host.editPeople(this.repo, a.row.number, a.what, { add: names, current: a.list }), cx);
  }

  removePerson(row, what, name, list, cx) {
    this.act(`Remove ${what}`, () => host.editPeople(this.repo, row.number, what, { remove: [name], current: list }), cx);
  }

  jobAction(kind, job, row, cx) {
    this.act(kind === "retry" ? (job.manual ? "Run job" : "Retry job") : "Cancel job",
      () => (kind === "retry" ? host.retryJob(this.repo, job) : host.cancelJob(this.repo, job)), cx);
  }

  retryPipeline(row, p, cx) { this.act("Retry failed jobs", () => host.retryPipeline(this.repo, p), cx); }

  openUrl(url) { if (url) exec("open", [url]).catch(() => exec("xdg-open", [url]).catch(() => {})); }

  // The job's log in a new terminal tab here.
  openLog(job, cx) {
    run("tab.new", { name: `Log: ${job.name}`.slice(0, 40), folder: this.repo.top, argv: host.jobLogArgv(this.repo, job) });
    this.close();
  }

  // The end of a failed job's log goes to the agent in this request's review tab; without one,
  // the review starts with it as the agent's first message.
  askAboutJob(row, job, cx) {
    const mark = this.mark(), tabName = `Review ${mark}${row.number}`;
    this.act("Ask AI", async () => {
      const tail = await host.jobLogTail(this.repo, job);
      const prompt = `The CI job "${job.name}" failed on ${this.repo.provider === "github" ? "pull" : "merge"} request ${mark}${row.number} `
        + `(${row.title}, branch ${row.branch}). The end of its log:\n\`\`\`\n${tail}\n\`\`\`\n`
        + "Find the cause in this branch's code and propose a fix. Don't push anything.";
      const a = agents().find((x) => x.tab_name === tabName);
      if (a) {
        const r = await hc(["send", a.address, prompt]);
        if (r.code !== 0) throw new Error((r.stderr || r.stdout).trim());
        this.note = `Sent to the agent in "${tabName}".`;
      } else this.pendingTask = prompt;
    }, cx, () => {});
  }

  start(row, cx, taskOverride = null) {
    if (!row || this.busy || !this.repo) return;
    const repo = this.repo, opt = this.option();
    this.busy = row; this.error = null; cx.notify();
    cx.spawn(async (cx) => {
      try {
        // Worktrees go under the home folder of the machine the repo is on.
        let userHome = home();
        if (repo.on) {
          const h = await exec("sh", ["-c", 'printf %s "$HOME"'], { on: repo.on });
          if (h.code !== 0 || !h.stdout.trim()) throw new Error(`Couldn't find the home folder on ${repo.on}`);
          userHome = h.stdout.trim();
        }
        const co = await checkout(repo, userHome, row);
        if (co.warnings.length) {
          try { notify({ title: "Redline: checkout may be stale", body: co.warnings.join("\n"), level: "warning", timeout: 15000 }); } catch { /* no toast mod */ }
        }
        const tabName = row.kind === "request" ? `Review ${this.mark()}${row.number}` : `Review ${row.branch}`;
        const before = tabIds();
        const what = row.kind === "request" ? `${repo.provider === "github" ? "pull" : "merge"} request ${this.mark()}${row.number} (${row.title})` : `branch ${row.branch}`;
        const gitDir = await git(co.path, ["rev-parse", "--absolute-git-dir"], repo.on);
        const findings = gitDir.ok ? `${gitDir.out}/redline-findings.json` : null;
        // An agent-less choice can't take a first message: use the first agent for one.
        const agentOpt = taskOverride && !opt?.argv ? this.options.find((o) => o.argv) : opt;
        const argv = agentOpt?.argv;
        const task = taskOverride ?? (findings ? opt?.task?.(row, what, findings) : undefined);
        const space = spaces().find((s) => (s.machine ?? null) === repo.on
          && panes().some((p) => p.cwd && (p.cwd === co.path || p.cwd.startsWith(co.path + "/")) && (s.tabs ?? []).some((t) => t.id === p.tab)));
        if (space) run("tab.new", { space: space.id, name: tabName, folder: co.path, argv, task });
        else run("space.new", { folder: co.path, machine: repo.on ?? "", tab: tabName, argv, task });

        // Wait for the new tab's terminal, then put the diff beside it.
        let pane = null, tab = null;
        for (let i = 0; i < 50 && !pane; i++) {
          await pause(100);
          tab = [...tabIds()].find((id) => !before.has(id));
          pane = tab ? panes().find((p) => p.tab === tab && p.terminal) : null;
        }
        if (!pane) throw new Error("The review tab didn't open");
        run("pane.split", {
          pane: pane.pane, direction: "right", mod: "redline",
          props: {
            redline: {
              provider: repo.provider, host: repo.host, repo: repo.repo, on: repo.on, folder: co.path,
              branch: co.branch, target: row.target, number: row.kind === "request" ? row.number : null,
              title: row.title ?? row.branch, url: row.url ?? null, tab, upstream: co.upstream, findings,
            },
          },
        });
        this.close();
      } catch (e) {
        this.error = msg(e); this.busy = null;
        try { notify({ title: "Redline", body: this.error, level: "error" }); } catch { /* no toast mod */ }
        cx.notify();
      }
    });
  }

  // ---- drawing ----

  button(t, id, label, onClick, { primary = false, disabled = false, tooltip = null } = {}) {
    return div().id(id).flex_none().h(28).px(12).flex().items_center().rounded(6).text_size(12)
      .when(primary, (e) => e.bg(disabled ? t.raised : t.solid).text_color(disabled ? t.dim : t.solid_foreground))
      .when(!primary, (e) => e.border_1().border_color(t.border).text_color(disabled ? t.dim : t.foreground))
      .when(!disabled, (e) => e.cursor_pointer().hover((s) => s.opacity(0.85)).on_click((_e, cx) => onClick(cx)))
      .when(Boolean(tooltip), (e) => e.tooltip(tooltip))
      .child(label);
  }

  // Pipeline dot, unresolved threads and a "you" badge for a request.
  extras(t, x) {
    const st = x.kind === "request" ? this.status2.byNumber[x.number] : null;
    if (!st) return [];
    const color = { success: t.ansi2, failed: t.ansi1, running: t.working, pending: t.dim, canceled: t.dim }[st.ci];
    return [
      st.ci ? div().flex_none().size(8).rounded(4).bg(color).tooltip(`Pipeline ${st.ci}`) : null,
      st.unresolved ? div().flex_none().text_size(10.5).text_color(t.blocked).child(`◆${st.unresolved}`).tooltip(`${st.unresolved} unresolved`) : null,
      this.waitingOnMe(x) ? div().flex_none().px(5).rounded(4).bg(t.accent + "30").text_size(10).text_color(t.accent).child("you") : null,
    ].filter(Boolean);
  }

  listRow(t, x, i) {
    const sel = i === this.at, busy = this.busy === x;
    return h_flex().id(`rv-row-${keyOf(x)}`).h(46).flex_none().px(10).gap(10).items_center().rounded(7).cursor_pointer()
      .when(sel, (e) => e.bg(t.selected)).hover((s) => s.bg(t.hover))
      .on_click((e, cx) => { this.at = i; this.select(cx); if (e.click_count > 1) this.start(x, cx); })
      .child(div().w(44).flex_none().text_size(11.5).text_color(x.kind === "request" ? t.accent : t.dim)
        .child(x.kind === "request" ? `${this.mark()}${x.number}` : "branch"))
      .child(v_flex().flex_1().min_w(0)
        .child(div().truncate().text_size(12.5).text_color(t.foreground).child(x.kind === "request" ? x.title : x.branch))
        .child(div().truncate().text_size(11).text_color(t.dim)
          .child(x.kind === "request"
            ? (this.filterMode === "mine"
              ? (this.status2.byNumber[x.number]?.blockers?.join(" · ") || "Ready to merge")
              : `${x.author}${x.draft ? " · draft" : ""}${x.fork ? " · fork" : ""}`)
            : `→ ${x.target}`)))
      .children(this.extras(t, x))
      .child(div().flex_none().text_size(11).text_color(busy ? t.accent : t.dim).child(busy ? "opening…" : ago(x.updated)));
  }

  // The dropdown beside Start review: what opens next to the diff.
  picker(t) {
    const opt = this.option();
    const groups = [...new Set(this.options.map((o) => o.group))];
    const list = v_flex().id("rv-options").min_w(320).max_h(420).overflow_y_scrollbar().p(5).gap(1).rounded(8)
      .bg(t.popover).border_1().border_color(t.border).shadow_md()
      .children(groups.flatMap((g) => [
        div().px(8).pt(6).pb(3).text_size(10.5).text_color(t.dim).child(g.toUpperCase()),
        ...this.options.filter((o) => o.group === g).map((o) => h_flex().id(`rv-opt-${o.id}`).h(30).px(8).gap(8).items_center().rounded(5)
          .cursor_pointer().text_size(12).when(o.id === this.choice, (e) => e.bg(t.selected)).hover((s) => s.bg(t.hover))
          .on_click((_e, cx) => this.choose(o.id, cx))
          .child(div().w(12).flex_none().text_color(t.accent).child(o.id === this.choice ? "✓" : ""))
          .child(div().flex_1().min_w(0).truncate().text_color(t.foreground).child(o.label))
          .when(Boolean(o.hint), (e) => e.child(div().flex_none().text_size(10.5).text_color(t.dim).child(o.hint)))),
      ]))
      .when(!this.options.length, (e) => e.child(div().p(8).text_size(12).text_color(t.dim).child("Loading…")));
    return Popover.new("rv-option-menu").open(Boolean(this.menu))
      .on_open_change((o, cx) => { this.menu = o; cx.notify(); })
      .trigger(h_flex().id("rv-option-trigger").h(28).px(10).gap(6).items_center().rounded(6).cursor_pointer().text_size(11.5)
        .border_1().border_color(this.menu ? t.accent : t.border).hover((s) => s.bg(t.hover)).tooltip("What opens beside the diff (Tab cycles)")
        .child(div().text_color(t.dim).child("with"))
        .child(div().text_color(t.foreground).child(opt ? opt.label : "…"))
        .child(div().text_size(9).text_color(t.dim).child("▾")))
      .content(list);
  }

  thread(t, row, th, i) {
    const open = this.replyTo === th.id;
    return v_flex().id(`rv-th-${i}`).flex_none().rounded(8).border_1().border_color(t.border).bg(t.background).overflow_hidden()
      .when(th.inline, (e) => e.child(h_flex().px(10).py(5).gap(8).items_center().bg(t.raised).text_size(11)
        .child(div().flex_1().min_w(0).truncate().text_color(t.muted).child(`${th.path}${th.line ? `:${th.line}` : ""}`))
        .when(th.resolvable, (e) => e.child(div().text_color(th.resolved ? t.ansi2 : t.blocked).child(th.resolved ? "resolved" : "unresolved")))))
      .children(th.notes.map((n, k) => v_flex().px(10).py(8).gap(4).when(k > 0, (e) => e.border_t(1).border_color(t.border))
        .child(h_flex().gap(8).text_size(11)
          .child(div().font_semibold().text_color(t.foreground).child(n.author))
          .child(div().text_color(t.dim).child(ago(n.at))))
        .child(div().w_full().text_size(12).child(TextView.markdown(`rv-n-${i}-${k}`, n.body || " ")))))
      .child(h_flex().px(10).py(5).gap(12).border_t(1).border_color(t.border).text_size(11.5)
        .child(div().id(`rv-reply-${i}`).text_color(t.accent).cursor_pointer()
          .on_click((_e, cx) => { this.replyTo = open ? null : th.id; if (!open) this.replyBox.focus(); cx.notify(); })
          .child(open ? "Cancel" : "Reply"))
        .when(th.resolvable, (e) => e.child(div().id(`rv-resolve-${i}`).text_color(t.muted).cursor_pointer()
          .on_click((_e, cx) => this.act(th.resolved ? "Unresolve" : "Resolve", () => host.resolve(this.repo, row.number, th, !th.resolved), cx))
          .child(th.resolved ? "Unresolve" : "Resolve"))))
      .when(open, (e) => e.child(v_flex().p(8).gap(6).border_t(1).border_color(t.border)
        .child(div().id("rv-reply-box").rounded(6).border_1().border_color(t.accent).p(6).cursor_text()
          .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
          .child(Textarea.new(this.replyBox).w_full().text_size(12).text_color(t.foreground)))
        .child(h_flex().justify_end().child(this.button(t, "rv-send-reply", this.busyAct === "Reply" ? "Sending…" : "Reply",
          (cx) => this.sendReply(row, th, cx), { primary: true, disabled: Boolean(this.busyAct) })))));
  }

  detail(t) {
    const row = this.current();
    if (!row) {
      return v_flex().flex_1().h_full().items_center().justify_center().gap(18)
        .child(logo(t, { size: 10 }))
        .child(div().text_size(12).text_color(t.dim).child(this.status ?? "Nothing selected."));
    }
    const d = this.details.get(keyOf(row)) ?? { loading: true };
    const isReq = row.kind === "request";
    const approved = d.approvedBy?.length ? `Approved by ${d.approvedBy.join(", ")}` : isReq && !d.loading ? "No approvals yet" : "";

    const head = v_flex().flex_none().px(18).pt(16).pb(12).gap(8).border_b(1).border_color(t.border)
      .child(h_flex().gap(10).items_center()
        .child(div().flex_none().text_size(13).text_color(isReq ? t.accent : t.dim).child(isReq ? `${this.mark()}${row.number}` : "branch"))
        .child(div().flex_1().min_w(0).truncate().text_size(15).font_semibold().child(isReq ? row.title : row.branch)))
      .child(div().text_size(11.5).text_color(t.muted).truncate()
        .child(`${isReq ? `${row.author} · ` : ""}${row.branch} → ${row.target}${row.draft ? " · draft" : ""}`))
      .when(Boolean(approved), (e) => e.child(div().text_size(11.5).text_color(d.approvedBy?.length ? t.ansi2 : t.dim).child(approved)))
      .child(h_flex().pt(4).gap(8).items_center()
        .when(isReq && !d.loading && !d.error, (e) => e.child(this.button(t, "rv-approve",
          this.busyAct === "Approve" ? "Approving…" : this.busyAct === "Unapprove" ? "Withdrawing…" : d.approvedByMe ? "✓ Approved" : "Approve",
          (cx) => this.approve(row, d, cx),
          { disabled: Boolean(this.busyAct) || (!d.approvedByMe && !d.canApprove) || (d.approvedByMe && this.repo?.provider === "github"),
            tooltip: d.approvedByMe ? (this.repo?.provider === "github" ? "Dismiss an approval on GitHub's website" : "Click to withdraw your approval") : null })))
        .child(this.button(t, "rv-start", this.busy ? "Opening…" : "Start review ▸", (cx) => this.start(row, cx),
          { primary: true, disabled: Boolean(this.busy), tooltip: "Check it out in a worktree and open a review tab (Enter)" }))
        .child(this.picker(t))
        .child(div().flex_1())
        .when(Boolean(row.url), (e) => e.child(this.button(t, "rv-open", "Open ↗",
          () => exec("open", [row.url]).catch(() => exec("xdg-open", [row.url]).catch(() => {}))))));

    const ci = isReq ? this.status2.byNumber[row.number]?.ci : null;
    const tabs = isReq ? [
      ["overview", "Overview"],
      ["comments", `Comments ${d.threads ? d.threads.length : ""}`],
      ["commits", `Commits ${d.commits ? d.commits.length : ""}`],
      ["pipeline", `${ci ? `${JOB_LOOK[ci]?.[0] ?? ""} ` : ""}Pipeline`],
      ["description", "Description"],
    ] : [["commits", `Commits ${d.commits ? d.commits.length : ""}`]];
    if (!tabs.some(([k]) => k === this.tab)) this.tab = tabs[0][0];
    const strip = h_flex().flex_none().px(14).gap(4).border_b(1).border_color(t.border)
      .children(tabs.map(([k, label]) => div().id(`rv-tab-${k}`).px(8).py(7).text_size(12).cursor_pointer()
        .border_b(2).border_color(this.tab === k ? t.accent : "#00000000")
        .text_color(this.tab === k ? t.foreground : k === "pipeline" && ci === "failed" ? t.ansi1 : t.muted)
        .on_click((_e, cx) => { this.tab = k; if (k === "pipeline") this.loadPipeline(row, cx); cx.notify(); })
        .child(label.trim())));

    let body;
    if (isReq && this.tab === "overview") body = overview(this, t, row);
    else if (isReq && this.tab === "pipeline") body = pipelineView(this, t, row);
    else if (d.loading) body = div().p(16).text_color(t.dim).child("Loading…");
    else if (d.error) body = div().p(16).text_size(12).text_color(t.ansi1).child(d.error);
    else if (this.tab === "commits") {
      body = v_flex().p(10).gap(1).children(d.commits.map((c, i) => h_flex().id(`rv-c-${i}`).h(30).flex_none().px(8).gap(10).items_center().rounded(5)
        .hover((s) => s.bg(t.hover))
        .child(div().w(70).flex_none().font_family("JetBrains Mono").text_size(11).text_color(t.accent).child(c.sha))
        .child(div().flex_1().min_w(0).truncate().text_size(12).child(c.title))
        .child(div().flex_none().text_size(11).text_color(t.dim).child(`${c.author} · ${ago(c.at)}`))))
        .when(!d.commits.length, (e) => e.child(div().p(8).text_color(t.dim).child("No commits ahead of the target.")));
    } else if (this.tab === "description") {
      body = div().p(16).text_size(12.5).child(d.description ? TextView.markdown(`rv-desc-${row.number}`, d.description) : "No description.");
    } else {
      body = v_flex().p(12).gap(10)
        .children(d.threads.map((th, i) => this.thread(t, row, th, i)))
        .when(!d.threads.length, (e) => e.child(div().p(4).text_color(t.dim).child("No comments yet.")))
        .child(v_flex().gap(6).pt(6)
          .child(div().id("rv-comment-box").rounded(6).border_1().border_color(t.border).p(6).cursor_text()
            .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
            .child(Textarea.new(this.commentBox).w_full().text_size(12).text_color(t.foreground)))
          .child(h_flex().justify_end().child(this.button(t, "rv-send-comment", this.busyAct === "Comment" ? "Posting…" : "Comment",
            (cx) => this.sendComment(row, cx), { disabled: Boolean(this.busyAct) }))));
    }

    return v_flex().flex_1().h_full().min_w(0).min_h(0)
      .child(head).child(strip)
      .when(Boolean(this.error), (e) => e.child(div().px(18).py(6).text_size(11.5).text_color(t.ansi1).child(this.error)))
      .when(Boolean(this.note) && !this.error, (e) => e.child(div().px(18).py(6).text_size(11.5).text_color(t.muted).child(this.note)))
      .child(div().id("rv-detail-body").flex_1().min_h(0).overflow_y_scrollbar().child(body));
  }

  render() {
    const t = theme(), rows = this.rows(), r = this.repo;
    if (this.at >= rows.length) this.at = Math.max(0, rows.length - 1);
    const nReq = rows.filter((x) => x.kind === "request").length;
    const gitlabLoginError = r?.provider === "gitlab" && this.requestError?.includes("invalid_grant");

    const left = v_flex().w(380).h_full().flex_none().min_h(0).border_r(1).border_color(t.border)
      .child(div().p(10).flex_none().child(h_flex().h(34).px(10).items_center().rounded(8).border_1().border_color(t.accent).bg(t.background)
        .child(Input.new(this.input).flex_1().h_full().text_size(12.5).text_color(t.foreground))))
      .when(Boolean(this.requestError), (e) => e.child(div().px(14).pb(6).text_size(11).text_color(t.blocked)
        .child(gitlabLoginError
          ? "GitLab CLI login needs renewal (invalid_grant). Run glab auth login --web in this repo's terminal, then click Recheck login."
          : this.requestError)))
      .child(v_flex().id("rv-list").flex_1().min_h(0).overflow_y_scrollbar().px(6).pb(8).gap(1)
        .child(h_flex().px(8).py(4).items_center()
          .child(div().flex_1().text_size(10.5).text_color(t.dim).child(`OPEN ${r?.provider === "github" ? "PULL" : "MERGE"} REQUESTS · ${nReq}`))
          .child(h_flex().gap(4)
            .children([["waiting", "Waiting on me"], ["mine", "My MRs"]].map(([k, label]) => div().id(`rv-filter-${k}`).px(6).py(1).rounded(10)
              .text_size(10.5).cursor_pointer().border_1().border_color(this.filterMode === k ? t.accent : t.border)
              .text_color(this.filterMode === k ? t.accent : t.muted)
              .on_click((_e, cx) => { this.filterMode = this.filterMode === k ? null : k; this.at = 0; this.select(cx); })
              .child(this.filterMode === k ? `✓ ${label}` : label)))))
        .children(rows.slice(0, nReq).map((x, i) => this.listRow(t, x, i)))
        .when(rows.length > nReq, (e) => e.child(div().px(8).pt(10).pb(4).text_size(10.5).text_color(t.dim).child("BRANCHES")))
        .children(rows.slice(nReq).map((x, i) => this.listRow(t, x, nReq + i)))
        .when(!this.status && !rows.length, (e) => e.child(div().p(10).text_color(t.dim).child("Nothing matches."))));

    return v_flex().id("review-dash").track_focus(this.view.handle).size_full().min_h(0)
      .bg(t.popover).text_size(13).text_color(t.foreground)
      .on_key_down((e, cx) => {
        const k = e.key;
        if (k === "escape") { if (this.typing) { this.input.focus(); cx.stop_propagation(); return; } return this.close(); }
        if (this.typing) return;
        if (k === "down") this.move(1, cx);
        else if (k === "up") this.move(-1, cx);
        else if (k === "tab") this.cycle(e.modifiers.shift ? -1 : 1, cx);
        else return;
        cx.stop_propagation();
      })
      .child(h_flex().h(44).flex_none().px(16).gap(10).items_center().border_b(1).border_color(t.border).bg(t.chrome)
        .child(div().text_size(14).font_semibold().child("Redline"))
        .child(div().flex_1().truncate().text_size(12).text_color(t.muted).child(r ? `${r.repo ?? r.name}${r.on ? ` · ${r.on}` : ""}` : ""))
        .when(Boolean(this.status), (e) => e.child(div().text_size(11.5).text_color(t.dim).child(this.status)))
        .child(this.button(t, "rv-refresh", gitlabLoginError ? "Recheck login" : "Refresh", (cx) => { this.details.clear(); this.load(cx); }))
        .child(div().text_size(11).text_color(t.dim).child("Esc")))
      .child(h_flex().flex_1().min_h(0).items_start().child(left).child(this.detail(t)));
  }
}
