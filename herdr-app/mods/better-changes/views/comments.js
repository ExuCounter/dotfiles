// Review comments: pick lines in a diff, note what's wrong, and send every note to an agent
// in this space as one message. Notes live in shared state per worktree, so they survive
// moving between files and reach whichever diff tab shows that worktree.
import { div } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { agents, hc, theme, shared, setShared } from "herdr";
import { TEXT, SIZE, TextBox, TextButton } from "./ui.js";

const COMMENTS = "better-changes.comments";
const NOTICE_MS = 4000;
const SNIPPET_LINES = 12;

const agentName = (agent) => agent?.tab_name || agent?.title || agent?.address || "agent";

export const commentMethods = {
  comments() {
    return (shared(COMMENTS) ?? {})[this.root] ?? [];
  },

  setComments(list) {
    setShared(COMMENTS, { ...(shared(COMMENTS) ?? {}), [this.root]: list });
  },

  // A click picks a line; shift-click stretches the pick from the first one.
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

  hasComment(row) {
    if (row?.next === undefined && row?.old === undefined) return false;
    return this.comments().some(
      (c) =>
        c.path === this.path &&
        c.scope === this.scope &&
        c.rows.some((r) => r.next === row.next && r.old === row.old && r.kind === row.kind),
    );
  },

  addComment(cx) {
    const note = this.commentInput.value().trim();
    const range = this.pickedRange();
    if (!note || !range?.rows.length) return;
    const rows = range.rows.map(({ kind, old, next, text }) => ({ kind, old, next, text }));
    this.setComments([
      ...this.comments(),
      { path: this.path, scope: this.scope, lines: this.linesLabel(rows), rows, note },
    ]);
    this.picked = null;
    this.commentInput.set_value("");
    this.diffFocus.focus();
    cx.notify();
  },

  cancelComment(cx) {
    this.picked = null;
    this.visual = false;
    this.commentInput.set_value("");
    this.diffFocus.focus();
    cx.notify();
  },

  removeComment(index, cx) {
    this.setComments(this.comments().filter((_, i) => i !== index));
    cx.notify();
  },

  spaceAgents() {
    return agents()
      .filter((a) => a.space === this.diffSpace)
      .sort((a, b) => b.seq - a.seq);
  },

  // The pick stays on the agent chosen last while it's still around; else the latest active.
  targetAgent() {
    const list = this.spaceAgents();
    return list.find((a) => a.address === this.agentAddress) ?? list[0] ?? null;
  },

  nextAgent(cx) {
    const list = this.spaceAgents();
    if (list.length < 2) return;
    const at = list.indexOf(this.targetAgent());
    this.agentAddress = list[(at + 1) % list.length].address;
    cx.notify();
  },

  reviewMessage(list) {
    const items = list.map((c, i) => {
      const shown = c.rows.slice(0, SNIPPET_LINES).map((r) => `${r.kind === " " ? " " : r.kind}${r.text}`);
      if (c.rows.length > SNIPPET_LINES) shown.push(`… ${c.rows.length - SNIPPET_LINES} more lines`);
      return [
        `${i + 1}. ${c.path}:${c.lines} (${c.scope})`,
        "```diff",
        ...shown,
        "```",
        c.note,
      ].join("\n");
    });
    return [
      `Review of the changes in ${this.root}. Address each comment; ask if one is unclear.`,
      "",
      items.join("\n\n"),
    ].join("\n");
  },

  sendComments(cx) {
    const agent = this.targetAgent();
    const list = this.comments();
    if (!agent || !list.length || this.sendingComments) return;
    this.sendingComments = true;
    this.commentError = null;
    cx.notify();
    cx.spawn(async (cx) => {
      try {
        const result = await hc(["send", agent.address, this.reviewMessage(list)]);
        if (result.code !== 0) throw new Error(result.stderr || "Agent delivery failed.");
        this.setComments([]);
        this.commentsOpen = false;
        this.commentNotice = `Sent ${list.length} to ${agentName(agent)}.`;
        cx.timer.after(NOTICE_MS, (cx) => {
          this.commentNotice = null;
          cx.notify();
        });
      } catch (e) {
        this.commentError = e.message; // The comments stay, so nothing is lost.
      } finally {
        this.sendingComments = false;
        cx.notify();
      }
    });
  },

  renderComments() {
    const t = theme();
    const list = this.comments();
    const range = this.pickedRange();
    const root = v_flex().flex_none().border_t(1).border_color(t.border).bg(t.raised);
    if (this.commentsOpen && list.length) root.child(this.renderCommentList(list));
    if (range) root.child(this.renderCommentBox(range));
    return root.child(this.renderCommentBar(list));
  },

  renderCommentBox(range) {
    const t = theme();
    return v_flex()
      .id("comment-box")
      .p(8)
      .gap(6)
      .on_key_down((e, cx) => {
        if (e.keystroke === "cmd-enter") this.addComment(cx);
        if (e.keystroke === "escape") this.cancelComment(cx);
      })
      .child(
        div()
          .text_size(TEXT.caption)
          .text_color(t.dim)
          .child(`Comment on ${this.path}:${this.linesLabel(range.rows)} · ⌘↩ add · esc cancel`),
      )
      .child(TextBox({ id: "comment-note", state: this.commentInput, focused: true, label: "Comment", height: 64 }))
      .child(
        h_flex()
          .gap(6)
          .child(TextButton({ id: "comment-add", label: "Add comment", active: true, onClick: (cx) => this.addComment(cx) }))
          .child(TextButton({ id: "comment-cancel", label: "Cancel", onClick: (cx) => this.cancelComment(cx) })),
      );
  },

  renderCommentList(list) {
    const t = theme();
    return v_flex()
      .id("comment-list")
      .max_h(180)
      .overflow_y_scroll()
      .px(8)
      .py(4)
      .gap(2)
      .children(
        list.map((c, i) =>
          h_flex()
            .gap(8)
            .items_start()
            .text_size(TEXT.small)
            .child(
              div()
                .flex_none()
                .text_color(t.accent)
                .child(`${c.path.split("/").pop()}:${c.lines}`),
            )
            .child(div().flex_1().min_w(0).whitespace_normal().child(c.note))
            .child(TextButton({ id: `comment-remove-${i}`, label: "✕", onClick: (cx) => this.removeComment(i, cx) })),
        ),
      );
  },

  renderCommentBar(list) {
    const t = theme();
    const agent = this.targetAgent();
    const several = this.spaceAgents().length > 1;
    const bar = h_flex()
      .h(SIZE.row)
      .px(8)
      .gap(6)
      .items_center()
      .text_size(TEXT.caption)
      .text_color(t.dim);
    if (this.commentError) bar.child(div().flex_1().min_w(0).truncate().text_color(t.ansi1).child(this.commentError));
    else if (this.commentNotice) bar.child(div().flex_1().min_w(0).truncate().child(this.commentNotice));
    else if (!list.length) {
      const { viewed, total } = this.reviewProgress();
      return bar.child(
        div()
          .flex_1()
          .truncate()
          .child(`${viewed}/${total} viewed · ⌃J ⌃K file · v viewed · j k gg G ⌃D ⌃U ]c [c move · ⇧V select · c comment`),
      );
    }
    else
      bar.child(
        TextButton({
          id: "comment-count",
          label: `${list.length} comment${list.length === 1 ? "" : "s"}`,
          active: this.commentsOpen,
          onClick: (cx) => {
            this.commentsOpen = !this.commentsOpen;
            cx.notify();
          },
        }),
      ).child(div().flex_1());
    if (!list.length) return bar;
    return bar
      .child(
        agent
          ? TextButton({
              id: "comment-agent",
              label: `to ${agentName(agent)}${several ? " ▾" : ""}`,
              onClick: (cx) => this.nextAgent(cx),
            })
          : div().text_color(t.ansi1).child("No agent in this space"),
      )
      .child(
        TextButton({
          id: "comment-send",
          label: this.sendingComments ? "Sending…" : "Send",
          active: Boolean(agent),
          onClick: (cx) => this.sendComments(cx),
        }),
      )
      .child(
        TextButton({
          id: "comment-clear",
          label: "Clear",
          onClick: (cx) => {
            this.setComments([]);
            this.commentsOpen = false;
            cx.notify();
          },
        }),
      );
  },
};
