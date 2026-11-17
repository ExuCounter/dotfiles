// A live review of what the diff shows: shift-r splits an interactive Claude under the diff,
// which reviews it the way a senior would, overview first and verdict last, in its own pane.
// Each finding it has checked also goes onto its line through bin/review-note (retracted if
// later reading disproves it); the diff reads those notes back as a strip on the line and a card
// under the diff at the cursor. a asks it about the picked lines; the answer
// shows under them. Nothing here edits code: a finding goes to the working agent through the
// review comments.
import { div } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { exec, run, hc, agents, panes, theme, shared, setShared, appHome } from "herdr";
import { TEXT, Icon, Markdown, TextButton, BarButton } from "./ui.js";
import { visibleMarkdown } from "./threads.js";

const REVIEWS = "better-changes.reviews";
const NOTE = `${appHome()}/mods/better-changes/bin/review-note`;
const POLL_MS = 1500;
const SNIPPET_LINES = 40;

// Reading only: the files, git's history, the MR on GitLab, and notes onto the diff.
const TOOLS = [
  "--allowedTools",
  "Read",
  "Grep",
  "Glob",
  "Bash(git diff:*)",
  "Bash(git show:*)",
  "Bash(git log:*)",
  "Bash(git blame:*)",
  "Bash(git status:*)",
  "Bash(glab mr view:*)",
  `Bash(${NOTE}:*)`,
  "--disallowedTools",
  "Edit",
  "Write",
  "NotebookEdit",
];

const SEVERITY = { blocker: 0, "should-fix": 1, question: 2, nit: 3 };
const severityColor = (severity, t) =>
  ({ blocker: t.ansi1, "should-fix": t.ansi3, question: t.ansi6 })[severity] ?? t.ansi4;
const onRow = (item, row) =>
  item.side === "old"
    ? row?.kind !== "+" && row?.old === item.line
    : row?.kind !== "-" && row?.next === item.line;
const quote = (text) => `'${text.replaceAll("'", `'\\''`)}'`;

export const reviewerMethods = {
  reviewerKey() {
    const commit = this.scope === "commit" ? `|${this.commitRef?.hash}` : "";
    return `${this.root}|${this.scope}${commit}`;
  },

  review() {
    return (shared(REVIEWS) ?? {})[this.reviewerKey()] ?? null;
  },

  setReview(key, change) {
    const all = shared(REVIEWS) ?? {};
    setShared(REVIEWS, { ...all, [key]: { ...(all[key] ?? {}), ...change } });
  },

  // The Claude in the split under this diff, while it runs.
  reviewerAgent() {
    const pane = this.review()?.pane;
    return pane ? (agents().find((a) => a.pane === pane) ?? null) : null;
  },

  // What the reviewer looks at: the MR, the branch, a commit or the working tree.
  reviewSubject() {
    const ahead = ["branch", "committed"].includes(this.scope) ? this.ahead(this.scope) : null;
    const mr = this.scope === "branch" ? this.branchRequest() : null;
    if (mr)
      return `merge request !${mr.iid} "${mr.title}" (${mr.url}), branch \`${ahead?.name ?? "HEAD"}\` → \`${mr.target}\`. The change is \`git diff ${ahead?.base ?? `origin/${mr.target}`}...HEAD\`; its description and threads are in \`glab mr view ${mr.iid} --comments\``;
    if (ahead) return `the commits on this branch: \`git diff ${ahead.base}...HEAD\``;
    if (this.scope === "commit" && this.commitRef?.hash) return `commit ${this.commitRef.hash}: \`git show ${this.commitRef.hash}\``;
    return "the uncommitted changes: `git diff HEAD` and the untracked files in `git status`";
  },

  howToNote(file) {
    const note = `${NOTE} ${quote(file)}`;
    return [
      `Everything goes onto the diff with \`${note} <kind> ...\` (allowed; for long text use a quoted heredoc, e.g. --body "$(cat <<'EOF' ... EOF)"):`,
      `- \`finding --path <repo path> --line <n> [--side old] --severity blocker|should-fix|nit|question --title "<short>" --body "<why it matters>" --checked "<what you read to confirm it>" --fix "<concrete fix>"\`: --line is the line in the new file; for a removed line use --side old and its old line. It prints the finding's id.`,
      `- \`retract --id <id> --reason "<what showed it's fine>"\`, when later reading disproves a finding.`,
      `- \`answer --id <id> --answer "<markdown>"\` for a question I send with an id; say it in the chat too.`,
    ].join("\n");
  },

  // A file in the repository's git folder holds the notes, one JSON line each.
  async reviewFile() {
    const result = await exec("git", ["rev-parse", "--absolute-git-dir"], { cwd: this.root });
    if (result.code !== 0) throw new Error("Not a git repository");
    const slug = this.reviewerKey().split("|").slice(1).join("-").replace(/[^\w.-]/g, "_");
    return `${result.stdout.trim()}/better-changes-review-${slug}.jsonl`;
  },

  // Splits Claude under the diff with the review as its first message.
  async startReviewer(task, cx) {
    const key = this.reviewerKey();
    const file = await this.reviewFile();
    await exec("/bin/sh", ["-c", ': > "$1"', "sh", file]);
    const diffPane = panes().find((p) => p.mod === "better-changes" && p.tab === this.diffTab())?.pane;
    const before = new Set(panes().map((p) => p.pane));
    this.setReview(key, { status: "live", file, pane: null, at: Date.now(), findings: [], answers: [], dismissed: [], error: null });
    run("pane.split", {
      direction: "down",
      pane: diffPane,
      argv: [
        "/bin/zsh",
        "-lc",
        'cd "$1" && shift && exec claude "$@"',
        "zsh",
        this.root,
        "--model",
        "claude-opus-5-5",
        ...TOOLS,
        "--",
        [task, "", this.howToNote(file)].join("\n"),
      ],
    });
    for (let i = 0; i < 40; i++) {
      const pane = panes().find((p) => !before.has(p.pane) && p.tab === this.diffTab());
      if (pane) {
        this.setReview(key, { pane: pane.pane });
        break;
      }
      await new Promise((resolve) => cx.timer.after(250, () => resolve()));
    }
    cx.notify();
  },

  startReview(cx) {
    const agent = this.reviewerAgent();
    if (agent) return run("pane.focus", { pane: agent.pane });
    const task = [
      `You're reviewing ${this.reviewSubject()}, in ${this.root}, as a senior engineer would, while I read the diff in Better Changes.`,
      "Don't change any code, commit, push or post on GitLab. Judge it by the repo's CLAUDE.md and the docs/ guides that apply.",
      "",
      "1. Understand it first: the MR's description and ticket, then the whole diff. Before any finding, give me the overview here, in this shape:",
      "   ## What this branch does: in plain words, what behaves differently once it's merged: before → after, for whom, and why it was needed. Name the feature or bug, not the files.",
      "   ## How: the approach in a few sentences, and anything surprising about it.",
      "   ## Walkthrough: each changed file in reading order, one line on its part.",
      "   ## Where the risk is: the parts you'll dig into, and why.",
      "2. Go deep where the risk is: migrations, concurrency, data integrity, money and permissions, public APIs, error paths, tests. Read the callers and the tests around each change.",
      "3. Put a finding on the diff only once you've checked it against the code, saying what you checked, and mention it here briefly. Something you can't settle from the code is a question, not a claim. Only real problems; none is a fine answer.",
      "4. If later reading shows a finding was wrong, retract it.",
      "5. End here with the verdict and your questions for the author, then wait for mine.",
    ].join("\n");
    cx.spawn(async (cx) => {
      try {
        await this.startReviewer(task, cx);
      } catch (e) {
        this.notice(`Review didn't start: ${e.message}`, cx);
      }
    });
  },

  toggleReview(cx) {
    this.startReview(cx);
  },

  // The notes file back into the review: findings not retracted, answers by id.
  pollReview(cx) {
    const key = this.reviewerKey();
    const review = this.review();
    if (!review?.file || this.reviewReading || Date.now() - (this.reviewReadAt ?? 0) < POLL_MS) return;
    this.reviewReading = true;
    this.reviewReadAt = Date.now();
    cx.spawn(async (cx) => {
      try {
        const result = await exec("/bin/cat", [review.file]);
        if (result.code !== 0 || result.stdout === this.reviewText) return;
        this.reviewText = result.stdout;
        const notes = result.stdout
          .split("\n")
          .filter((line) => line.trim())
          .flatMap((line) => {
            try {
              return [JSON.parse(line)];
            } catch {
              return [];
            }
          });
        const retracted = Object.fromEntries(notes.filter((note) => note.kind === "retract").map((note) => [note.id, note.reason]));
        const findings = notes.filter((note) => note.kind === "finding" && !(note.id in retracted));
        const replies = Object.fromEntries(notes.filter((note) => note.kind === "answer").map((note) => [note.id, note.answer]));
        const now = (shared(REVIEWS) ?? {})[key] ?? {};
        this.setReview(key, {
          findings,
          answers: (now.answers ?? []).map((a) => (replies[a.id] ? { ...a, status: "done", answer: replies[a.id] } : a)),
        });
        cx.notify();
      } finally {
        this.reviewReading = false;
      }
    });
  },

  // ── Questions about lines ─────────────────────────────────────────────────

  startAsk(cx) {
    this.asking = true;
    this.openComment(cx);
  },

  sendQuestion(cx) {
    const question = this.commentInput.value().trim();
    const range = this.pickedRange();
    if (!question || !range?.rows.length) return;
    const rows = range.rows.map(({ kind, old, next, text }) => ({ kind, old, next, text }));
    const shown = rows.slice(0, SNIPPET_LINES).map((r) => `${r.kind}${r.text}`);
    if (rows.length > SNIPPET_LINES) shown.push(`… ${rows.length - SNIPPET_LINES} more lines`);
    const last = rows[rows.length - 1];
    const answer = {
      id: `q${Date.now().toString(36)}`,
      path: this.path,
      lines: this.linesLabel(rows),
      line: last.next ?? last.old,
      side: last.next != null ? "new" : "old",
      question,
      status: "running",
    };
    this.asking = false;
    this.picked = null;
    this.commentInput.set_value("");
    this.diffFocus.focus();
    const message = [
      `Question ${answer.id}, about ${this.path}:${answer.lines}:`,
      "```diff",
      ...shown,
      "```",
      question,
    ].join("\n");
    this.askReviewer(answer, message, cx, (error) => (this.commentError = error));
  },

  // Whether a review thread is right and what fixing it takes; the answer shows on its card.
  askThread(thread, cx) {
    const answer = { id: `q${Date.now().toString(36)}`, thread: thread.id, question: "Is it right, and what's the fix?", status: "running" };
    const quoted = thread.notes.flatMap((note) => [`**${note.name}:**`, visibleMarkdown(note.body), ""]);
    const message = [
      `Question ${answer.id}, about a review thread on ${thread.path == null ? "the merge request" : `${thread.path}${thread.line == null ? "" : `:${thread.line}`}`}:`,
      "",
      ...quoted,
      "Is it right, judged against the code as it is now? If it is, what would the fix be? If not, why not, in a line I could reply with.",
    ].join("\n");
    this.askReviewer(answer, message, cx, (error) => (this.threadError = error));
    this.noteActivity(thread.id, { asked: Date.now() });
  },

  threadAnswers(thread) {
    const review = this.review();
    const gone = new Set(review?.dismissed ?? []);
    return (review?.answers ?? []).filter((a) => a.thread === thread.id && !gone.has(a.id));
  },

  // To the reviewer under the diff, or a new one started on the question.
  askReviewer(answer, message, cx, onError) {
    const agent = this.reviewerAgent();
    const key = this.reviewerKey();
    cx.spawn(async (cx) => {
      try {
        if (agent) {
          const result = await hc(["send", agent.address, message]);
          if (result.code !== 0) throw new Error(result.stderr || "The reviewer didn't get it.");
        } else {
          const task = [
            `I'm reading ${this.reviewSubject()}, in ${this.root}, in Better Changes. Don't change any code, commit, push or post on GitLab.`,
            "",
            message,
          ].join("\n");
          await this.startReviewer(task, cx);
        }
        const now = (shared(REVIEWS) ?? {})[key] ?? {};
        this.setReview(key, { answers: [...(now.answers ?? []), answer] });
      } catch (e) {
        onError(e.message);
      }
      cx.notify();
    });
  },

  // ── On the diff ───────────────────────────────────────────────────────────

  findingsAt(row) {
    const review = this.review();
    if (!row || !review) return [];
    const gone = new Set(review.dismissed ?? []);
    return [
      ...(review.findings ?? []).filter((f) => !gone.has(f.id) && f.path === this.path && onRow(f, row)),
      ...(review.answers ?? []).filter((a) => !gone.has(a.id) && a.path === this.path && onRow(a, row)),
    ];
  },

  findingColor(row) {
    const here = this.findingsAt(row);
    if (!here.length) return null;
    const t = theme();
    const worst = here.filter((f) => f.severity).sort((a, b) => SEVERITY[a.severity] - SEVERITY[b.severity])[0];
    return worst ? severityColor(worst.severity, t) : t.accent;
  },

  liveFindings(review = this.review()) {
    const gone = new Set(review?.dismissed ?? []);
    return (review?.findings ?? []).filter((f) => !gone.has(f.id));
  },

  fileFindingCount(path, scope) {
    const review = (shared(REVIEWS) ?? {})[`${this.root}|${scope}`];
    return this.liveFindings(review).filter((f) => f.path === path).length;
  },

  dismissFinding(id, cx) {
    const review = this.review();
    if (!review) return;
    this.setReview(this.reviewerKey(), { dismissed: [...(review.dismissed ?? []), id] });
    cx.notify();
  },

  // A finding straight to the working agent, on its line; once it's there, off the diff.
  findingToAgent(finding, cx) {
    const index = this.rows.findIndex((row) => onRow(finding, row));
    const rows = index >= 0 ? [this.commentRow(index)] : [];
    const note = [`**${finding.title}**`, finding.body, finding.fix ? `Fix: ${finding.fix}` : ""].filter(Boolean).join("\n\n");
    this.deliverToAgent([{ path: finding.path, scope: this.scope, lines: String(finding.line), rows, note }], cx, () =>
      this.dismissFinding(finding.id, cx),
    );
  },

  renderFinding(item) {
    const t = theme();
    const color = item.severity ? severityColor(item.severity, t) : t.accent;
    const header = h_flex()
      .gap(6)
      .items_center()
      .text_size(TEXT.small)
      .child(
        h_flex()
          .flex_none()
          .px(6)
          .h(20)
          .gap(4)
          .items_center()
          .rounded(10)
          .bg(`${color}22`)
          .text_color(color)
          .child(Icon(item.severity ? "circle-dot" : "message", 12))
          .child(item.severity ?? "answer"),
      )
      .child(
        div()
          .flex_1()
          .min_w(0)
          .font_semibold()
          .text_color(t.foreground)
          .child(item.title ?? item.question),
      )
      .when(Boolean(item.severity), (el) =>
        el.child(TextButton({ id: `finding-agent-${item.id}`, label: "Add to review", onClick: (cx) => this.findingToAgent(item, cx) })),
      )
      .child(TextButton({ id: `finding-dismiss-${item.id}`, label: "Dismiss", onClick: (cx) => this.dismissFinding(item.id, cx) }));
    const card = v_flex().gap(4).pl(8).border_l(2).border_color(color).child(header);
    if (item.severity) {
      card.child(Markdown(`finding-body-${item.id}`, item.body));
      if (item.fix) card.child(Markdown(`finding-fix-${item.id}`, `**Fix:** ${item.fix}`));
      if (item.checked)
        card.child(div().text_size(TEXT.small).text_color(t.dim).child(`Checked: ${item.checked}`));
    } else if (item.status === "running") card.child(div().text_size(TEXT.small).text_color(t.dim).child("Thinking…"));
    else card.child(Markdown(`answer-${item.id}`, item.answer || " "));
    return card;
  },

  // The findings and answers on the cursor's line, under the diff.
  renderLineReview() {
    const here = this.findingsAt(this.rows[this.cursor]);
    if (!here.length) return null;
    const t = theme();
    return v_flex()
      .id("line-review")
      .max_h(320)
      .overflow_y_scroll()
      .p(8)
      .gap(10)
      .border_b(1)
      .border_color(t.border)
      .children(here.map((item) => this.renderFinding(item)));
  },

  ReviewButton() {
    const t = theme();
    const review = this.review();
    const agent = this.reviewerAgent();
    const findings = this.liveFindings(review);
    const blockers = findings.filter((f) => f.severity === "blocker").length;
    const count = findings.length ? ` · ${findings.length} finding${findings.length === 1 ? "" : "s"}` : "";
    const label = !review ? "Review" : agent?.status === "working" ? `Reviewing…${count}` : `Review${count || " · no findings"}`;
    return BarButton({
      id: "review-start",
      icon: "eye",
      active: Boolean(agent),
      tooltip: agent ? "Go to the reviewer below (⇧R)" : "Claude reviews the change in a pane below (⇧R)",
      onClick: (cx) => this.toggleReview(cx),
      children: [div().when(blockers > 0, (el) => el.text_color(t.ansi1)).child(label)],
    });
  },
};
