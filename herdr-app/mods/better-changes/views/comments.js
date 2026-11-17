// Review comments: pick lines in a diff, note what's wrong, and send the note to an agent in
// this space or post it as a thread on the branch's merge request, each one as it's written.
import { div } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { agents, exec, hc, run, theme } from "herdr";
import { TEXT, Icon, TextBox, TextButton, BarButton, PillButton } from "./ui.js";
import { settleInbox } from "./threads.js";
import { diffRefs, pathHash, createDiscussion, approve } from "../git/merge-request.js";

const NOTICE_MS = 4000;
const SNIPPET_LINES = 12;
// A space with no agent gets one for the review, in a tab of its own.
const NEW_AGENT = ["claude", "--model", "claude-opus-5-5", "--permission-mode", "acceptEdits"];

const agentName = (agent) => agent?.tab_name || agent?.title || agent?.address || "agent";

// hc says why it didn't type into the agent as JSON; a dialog on its screen (a question, a
// permission prompt) would take the message as its answer, so hc holds it back.
function sendError(agent, text) {
  let error;
  try {
    error = JSON.parse(text).error;
  } catch {
    return text?.trim() || "Agent delivery failed.";
  }
  if (error?.kind === "blocked") return `${agentName(agent)} is waiting on you in its pane (${/\((.+)\)/.exec(error.message)?.[1] ?? "a dialog"}); answer it there, then send again.`;
  return error?.message ?? "Agent delivery failed.";
}

// hc send waits while the agent's prompt holds a half-typed message.
const SEND_TIMEOUT_MS = 15000;

export const commentMethods = {
  pickLine(index, shift, cx) {
    const row = this.rows[index];
    if (!row || !["+", "-", " "].includes(row.kind)) return;
    if (shift && this.picked) this.picked = { ...this.picked, end: index };
    else this.picked = { start: index, end: index };
    this.cursor = index;
    this.visual = false;
    this.commentError = null;
    this.commentInput.focus();
    cx.notify();
  },

  pickedRange() {
    if (!this.picked) return null;
    const from = Math.min(this.picked.start, this.picked.end);
    const to = Math.max(this.picked.start, this.picked.end);
    return { from, to, rows: this.rows.slice(from, to + 1).filter((r) => r.kind !== "@") };
  },

  isPicked(row) {
    const range = this.pickedRange();
    if (!range) return false;
    const index = this.rows.indexOf(row);
    return index >= range.from && index <= range.to;
  },

  // Lines are named by the new file's numbers; a pick of removed lines only, by the old ones.
  linesLabel(rows) {
    const after = rows.map((r) => r.next).filter((n) => n !== undefined);
    const numbers = after.length ? after : rows.map((r) => r.old).filter((n) => n !== undefined);
    if (!numbers.length) return "";
    const first = Math.min(...numbers);
    const last = Math.max(...numbers);
    const span = first === last ? `${first}` : `${first}-${last}`;
    return after.length ? span : `${span} (removed)`;
  },

  // The row with both sides' line numbers: an added line sits before the old file's next
  // line, a removed one before the new file's. GitLab anchors a range by them.
  commentRow(index) {
    const row = this.rows[index];
    const within = (step, side) => {
      for (let i = index + step; i >= 0 && i < this.rows.length && this.rows[i].kind !== "@"; i += step)
        if (this.rows[i][side] !== undefined) return this.rows[i][side] + (step < 0 ? 1 : 0);
      return undefined;
    };
    const at = (side) => row[side] ?? within(1, side) ?? within(-1, side);
    return { kind: row.kind, old: row.old, next: row.next, text: row.text, oldAt: at("old"), nextAt: at("next") };
  },

  pickedComment() {
    const note = this.commentInput.value().trim();
    const range = this.pickedRange();
    if (!note || !range?.rows.length) return null;
    const rows = range.rows.map((row) => this.commentRow(this.rows.indexOf(row)));
    return { path: this.path, scope: this.scope, lines: this.linesLabel(rows), rows, note };
  },

  closeCommentBox(cx) {
    this.picked = null;
    this.commentInput.set_value("");
    this.diffFocus.focus();
    cx.notify();
  },

  sendComment(cx) {
    const comment = this.pickedComment();
    if (comment) this.deliverToAgent([comment], cx, () => this.closeCommentBox(cx));
  },

  // A thread on the line on GitLab; one GitLab can't anchor quotes its lines instead.
  postComment(cx) {
    const mr = this.branchRequest();
    const comment = this.pickedComment();
    if (!mr || !comment || this.submitting) return;
    this.submitting = true;
    this.commentError = null;
    cx.notify();
    cx.spawn(async (cx) => {
      try {
        const refs = await diffRefs(mr);
        const head = (await exec("git", ["rev-parse", "HEAD"], { cwd: this.root })).stdout.trim();
        if (head !== refs.head_sha)
          throw new Error(`This checkout is at ${head.slice(0, 8)}, !${mr.iid} at ${refs.head_sha.slice(0, 8)}: pull or push, then post.`);
        const position = await this.draftPosition(comment, refs);
        const posted = position ? await createDiscussion(mr, comment.note, position).catch(() => null) : null;
        if (!posted) await createDiscussion(mr, this.fileNote(comment), null);
        this.closeCommentBox(cx);
        this.notice(`Posted on !${mr.iid}.`, cx);
        this.refreshThreads(cx, true);
      } catch (e) {
        this.commentError = e.message; // The note stays in the box.
      } finally {
        this.submitting = false;
        cx.notify();
      }
    });
  },

  approveRequest(cx) {
    const mr = this.branchRequest();
    if (!mr || this.approving) return;
    this.approving = true;
    cx.notify();
    cx.spawn(async (cx) => {
      try {
        await approve(mr);
        this.notice(`Approved !${mr.iid}.`, cx);
      } catch (e) {
        this.commentError = e.message;
      } finally {
        this.approving = false;
        cx.notify();
      }
    });
  },

  cancelComment(cx) {
    this.asking = false;
    this.picked = null;
    this.visual = false;
    this.commentInput.set_value("");
    this.diffFocus.focus();
    cx.notify();
  },

  // Claude's reviewer under the diff only reads; the comments go to the agent doing the work.
  spaceAgents() {
    const reviewer = this.review()?.pane;
    return agents()
      .filter((a) => a.space === this.diffSpace && a.pane !== reviewer)
      .sort((a, b) => b.seq - a.seq);
  },

  // The pick stays on the agent chosen last while it's still around; else the latest active.
  targetAgent() {
    const list = this.spaceAgents();
    return list.find((a) => a.address === this.agentAddress) ?? list[0] ?? null;
  },

  reviewMessage(list) {
    const items = list.map((c, i) => {
      const shown = c.rows.slice(0, SNIPPET_LINES).map((r) => `${r.kind === " " ? " " : r.kind}${r.text}`);
      if (c.rows.length > SNIPPET_LINES) shown.push(`… ${c.rows.length - SNIPPET_LINES} more lines`);
      const code = shown.length ? ["```diff", ...shown, "```"] : [];
      return [`${i + 1}. ${c.path}${c.lines ? `:${c.lines}` : ""} (${c.scope})`, ...code, c.note, ...(c.report ? ["", c.report] : [])].join("\n");
    });
    return [
      `Review of the changes in ${this.root}. Address each comment; ask if one is unclear.`,
      "",
      items.join("\n\n"),
    ].join("\n");
  },

  // The review as a new agent's first message. `onSent` clears what was sent; by default the
  // review comments.
  startAgent(list, cx, onSent = () => {}) {
    run("tab.new", {
      space: this.diffSpace,
      name: "Review",
      folder: this.root,
      argv: NEW_AGENT,
      task: this.reviewMessage(list),
    });
    this.settleSentThreads(list);
    onSent();
    this.notice(`Started Claude with ${list.length} comment${list.length === 1 ? "" : "s"}.`, cx);
  },

  settleSentThreads(list) {
    const mr = this.branchRequest();
    if (mr) for (const comment of list) if (comment.thread) settleInbox(mr, comment.thread, "sent");
  },

  notice(text, cx) {
    this.commentNotice = text;
    cx.notify();
    cx.timer.after(NOTICE_MS, (cx) => {
      if (this.commentNotice !== text) return;
      this.commentNotice = null;
      cx.notify();
    });
  },

  // A comment GitLab can anchor: on the branch's diff, with both sides' numbers.
  async draftPosition(comment, refs) {
    const rows = comment.rows.filter((r) => r.old !== undefined || r.next !== undefined);
    if (comment.scope !== "branch" || !rows.length) return null;
    const hash = await pathHash(comment.path);
    const point = (r) => ({
      line_code: `${hash}_${r.oldAt}_${r.nextAt}`,
      type: r.kind === "+" ? "new" : r.kind === "-" ? "old" : null,
      old_line: r.kind === "+" ? null : r.old,
      new_line: r.kind === "-" ? null : r.next,
    });
    const first = rows[0];
    const last = rows[rows.length - 1];
    const ranged = rows.length > 1 && first.oldAt !== undefined && last.oldAt !== undefined;
    return {
      base_sha: refs.base_sha,
      start_sha: refs.start_sha,
      head_sha: refs.head_sha,
      position_type: "text",
      old_path: comment.path,
      new_path: comment.path,
      old_line: last.kind === "+" ? null : last.old,
      new_line: last.kind === "-" ? null : last.next,
      ...(ranged ? { line_range: { start: point(first), end: point(last) } } : {}),
    };
  },

  // A comment GitLab can't anchor goes in the review as a note quoting its lines.
  fileNote(comment) {
    const code = comment.rows.slice(0, SNIPPET_LINES).map((r) => `${r.kind === " " ? " " : r.kind}${r.text}`);
    return [`\`${comment.path}${comment.lines ? `:${comment.lines}` : ""}\``, "```diff", ...code, "```", comment.note].join("\n");
  },

  // To the agent the bar targets, or a new one when there's none.
  deliverToAgent(list, cx, onSent = () => {}, onError = (error) => (this.commentError = error)) {
    const agent = this.targetAgent();
    if (this.sendingComments) return;
    if (!agent) return this.startAgent(list, cx, onSent);
    this.sendingComments = true;
    this.commentError = null;
    cx.notify();
    cx.spawn(async (cx) => {
      try {
        const result = await Promise.race([
          hc(["send", agent.address, this.reviewMessage(list)]),
          new Promise((done) => cx.timer.after(SEND_TIMEOUT_MS, () => done({ code: 1, stderr: `${agentName(agent)} has an unsent draft in its prompt; send it or clear it, then try again.` }))),
        ]);
        if (result.code !== 0) throw new Error(sendError(agent, result.stderr || result.stdout));
        this.settleSentThreads(list);
        onSent();
        this.notice(`Sent ${list.length} to ${agentName(agent)}.`, cx);
      } catch (e) {
        onError(e.message); // What was to be sent stays, so nothing is lost.
      } finally {
        this.sendingComments = false;
        cx.notify();
      }
    });
  },

  renderComments() {
    const t = theme();
    const range = this.pickedRange();
    const root = v_flex().flex_none().border_t(1).border_color(t.border).bg(t.raised);
    const lineReview = this.renderLineReview();
    if (lineReview) root.child(lineReview);
    const threads = this.renderThreads();
    if (threads) root.child(threads);
    if (range) root.child(this.renderCommentBox(range));
    return root.child(this.renderCommentBar());
  },

  renderCommentBox(range) {
    const t = theme();
    const where = `${this.path}:${this.linesLabel(range.rows)}`;
    return v_flex()
      .id("comment-box")
      .p(8)
      .gap(6)
      .on_key_down((e, cx) => {
        this.keyFromBox = true;
        if (e.keystroke === "cmd-enter") this.asking ? this.sendQuestion(cx) : this.sendComment(cx);
        if (["shift-cmd-enter", "cmd-shift-enter"].includes(e.keystroke) && !this.asking) this.postComment(cx);
        if (e.keystroke === "escape") this.cancelComment(cx);
      })
      .child(
        div()
          .text_size(TEXT.small)
          .text_color(this.asking ? t.accent : t.muted)
          .child(this.asking ? `Ask Claude about ${where}` : `Comment on ${where}`),
      )
      .child(
        TextBox({
          id: "comment-note",
          state: this.commentInput,
          focused: true,
          label: this.asking ? "Question" : "Comment",
          height: 64,
        }),
      )
      .child(
        h_flex()
          .gap(6)
          .items_center()
          .when(this.asking, (el) =>
            el.child(PillButton({ id: "comment-ask", icon: "sparkles", label: "Ask Claude", hint: "⌘↩", tone: "primary", onClick: (cx) => this.sendQuestion(cx) })),
          )
          .when(!this.asking, (el) =>
            el
              .child(
                PillButton({
                  id: "comment-send",
                  icon: "send",
                  label: this.sendingComments ? "Sending…" : "Send to agent",
                  hint: "⌘↩",
                  tone: "primary",
                  onClick: (cx) => this.sendComment(cx),
                }),
              )
              .when(Boolean(this.branchRequest()), (el) =>
                el.child(
                  PillButton({
                    id: "comment-post",
                    icon: "external-link",
                    label: this.submitting ? "Posting…" : "Post on GitLab",
                    hint: "⇧⌘↩",
                    onClick: (cx) => this.postComment(cx),
                  }),
                ),
              ),
          )
          .child(TextButton({ id: "comment-cancel", label: "Cancel · esc", onClick: (cx) => this.cancelComment(cx) })),
      );
  },



  // Threads, viewed files and comments on the left; sending them on the right.
  renderCommentBar() {
    const t = theme();
    const { viewed, total } = this.reviewProgress();
    const bar = h_flex().h(36).px(8).gap(8).items_center().text_size(TEXT.body).text_color(t.muted);
    const threads = this.ThreadsButton();
    if (threads) bar.child(threads);
    bar.child(
      h_flex()
        .flex_none()
        .gap(5)
        .items_center()
        .text_color(total && viewed === total ? t.ansi2 : t.muted)
        .child(Icon("check", 14))
        .child(`${viewed}/${total} viewed`),
    );
    const message = this.commentError ?? this.commentNotice;
    bar.child(
      div()
        .flex_1()
        .min_w(0)
        .truncate()
        .text_color(this.commentError ? t.ansi1 : t.dim)
        .child(message ?? ""),
    );
    const mr = this.branchRequest();
    const me = this.threadState()?.me;
    if (mr && me != null && mr.author !== me)
      bar.child(
        BarButton({
          id: "approve",
          icon: "check",
          tooltip: `Approve !${mr.iid} on GitLab`,
          onClick: (cx) => this.approveRequest(cx),
          children: [div().child(this.approving ? "Approving…" : "Approve")],
        }),
      );
    return bar.child(this.ReviewButton()).child(this.KeysButton());
  },
};
