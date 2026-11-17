// The merge request's review threads on the branch diff: a strip on each line a thread is
// on, the threads under the cursor in a panel below the diff, and with t the review queue, what
// still waits on someone across the request, one card at a time. A thread can be answered,
// resolved, or handed to the agent as a review comment.
import { div } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { exec, theme, shared, setShared, readTextFile, appHome } from "herdr";
import { readThreads, readMe, replyToThread, resolveThread } from "../git/merge-request.js";
import { reviewQueue, excerpt, threadResults } from "../git/review-queue.js";
import { TEXT, SIZE, Icon, IconButton, Markdown, TextBox, TextButton, BarButton, PillButton } from "./ui.js";

const THREADS = "better-changes.threads";
// The review inbox (Better Sidebar's mr-inbox): what to open, and what's been dealt with.
const INBOX = "mr-inbox";
const OPEN_THREAD = "better-changes.open-thread";
// Comments dismissed from the queue, shared with Better Sidebar: thread id -> last note's time.
const DISMISSED = "review-queue.dismissed";
// What happened to each thread, shared with Better Sidebar: thread id -> { sent, asked, result }.
const ACTIVITY = "review-queue.activity";
const THREAD_NOTE = `${appHome()}/mods/better-changes/bin/thread-note`;
const NOTES_POLL_MS = 1500;
const quote = (text) => `'${text.replace(/'/g, "'\\''")}'`;
const resultReply = (result) =>
  result.kind === "not-fixed" ? `Not fixing: ${result.reason}` : `Fixed in ${result.commit}.`;
const clock = (at) => new Date(at).toTimeString().slice(0, 5);
const OPEN_THREAD_MS = 60000;
const STALE_MS = 60000;
const CLAMP_LINES = 3;
const loading = new Set();

// The inbox's item for a thread stays quiet until someone writes on it again.
export function settleInbox(mr, threadId, status) {
  const state = shared(INBOX);
  const key = `${mr.repo}!${mr.iid}#${threadId}`;
  const item = state?.items?.[key];
  if (!item) return;
  setShared(INBOX, { ...state, items: { ...state.items, [key]: { ...item, status, handledAt: Date.now() } } });
}

// Bots hide their bookkeeping in HTML comments; the renderer would print it.
export const visibleMarkdown = (body) => body.replace(/<!--[\s\S]*?-->/g, "").trim() || " ";

const keyOf = (mr) => `${mr.host}/${mr.repo}!${mr.iid}`;
const onRow = (thread, row) =>
  thread.side === "new"
    ? row?.kind !== "-" && row?.next === thread.line
    : row?.kind !== "+" && row?.old === thread.line;

export const threadMethods = {
  branchRequest() {
    return this.ahead("branch")?.mergeRequest ?? null;
  },

  threadState() {
    const mr = this.branchRequest();
    return mr ? ((shared(THREADS) ?? {})[keyOf(mr)] ?? null) : null;
  },

  mrThreads() {
    return this.threadState()?.list ?? [];
  },

  refreshThreads(cx, force = false) {
    const mr = this.branchRequest();
    if (!mr) return;
    const key = keyOf(mr);
    const state = (shared(THREADS) ?? {})[key];
    if (loading.has(key) || (!force && state && Date.now() - state.at < STALE_MS)) return;
    loading.add(key);
    cx.spawn(async (cx) => {
      let next;
      try {
        const [list, me] = await Promise.all([readThreads(mr), readMe(mr.host)]);
        next = { at: Date.now(), list, me, error: null };
      } catch (e) {
        next = { at: Date.now(), list: state?.list ?? [], me: state?.me, error: e.message };
      } finally {
        loading.delete(key);
      }
      setShared(THREADS, { ...(shared(THREADS) ?? {}), [key]: next });
      cx.notify();
    });
  },

  // What GitLab will have once a write lands, shown straight away; the read after the write
  // puts back what GitLab really has if it failed.
  settleLocally(thread, { reply, resolved }) {
    const mr = this.branchRequest();
    const state = this.threadState();
    if (!mr || !state) return;
    const list = state.list.map((each) =>
      each.id !== thread.id
        ? each
        : {
            ...each,
            resolved: each.resolvable && resolved ? true : each.resolved,
            notes: reply ? [...each.notes, { authorId: state.me, author: "", name: "", bot: false, body: reply, at: Date.now() }] : each.notes,
          },
    );
    setShared(THREADS, { ...(shared(THREADS) ?? {}), [keyOf(mr)]: { ...state, list } });
  },

  // The sidebar reads GitLab on its own clock; a dismissal at the thread's last note hides it
  // there until then, and a resolved thread doesn't come back.
  hideInSidebar(thread) {
    const notes = thread.notes;
    setShared(DISMISSED, { ...(shared(DISMISSED) ?? {}), [thread.id]: notes[notes.length - 1].at });
  },

  reviewQueue() {
    const state = this.threadState();
    return state?.me == null ? [] : reviewQueue(state.list, state.me, shared(DISMISSED) ?? {});
  },

  fileThreads(path = this.path) {
    return this.mrThreads().filter((thread) => thread.path === path);
  },

  openThreadCount(path) {
    return this.fileThreads(path).filter((thread) => thread.resolvable && !thread.resolved).length;
  },

  threadsAt(row) {
    if (this.scope !== "branch" || !row) return [];
    return this.fileThreads().filter((thread) => onRow(thread, row));
  },

  // The strip's colour: a review comment of ours, an open thread, a resolved one.
  threadColor(row) {
    const threads = this.threadsAt(row);
    if (!threads.length) return null;
    const t = theme();
    return threads.some((thread) => !thread.resolved) ? t.ansi5 : t.dim;
  },

  // The sidebar opens the branch file a thread from the inbox is on, or its first file. A
  // request for the queue with no thread named opens on the queue's first item.
  openRequestedThread(cx) {
    const request = shared(OPEN_THREAD);
    if (!request || Date.now() - request.at > OPEN_THREAD_MS) return;
    const ahead = this.branchAhead;
    const mr = ahead?.mergeRequest;
    if (!mr || mr.iid !== request.iid || mr.repo !== request.repo) return;
    let { thread, path } = request;
    if (request.queue && !thread) {
      const state = this.threadState();
      if (state?.me == null && !state?.error) return this.refreshThreads(cx);
      const first = this.reviewQueue()[0];
      thread = first?.id;
      path = first?.path;
    }
    setShared(OPEN_THREAD, null);
    const file = ahead.files.find((f) => f.path === path) ?? ahead.files[0];
    if (file) this.pick(file, "branch", cx, { thread, queue: Boolean(request.queue && thread) });
  },

  // The diff puts its cursor on the thread once a read newer than the request has it. A line
  // the changes leave out shows once the diff is of the whole file.
  revealThread(cx) {
    const want = this.focusThread;
    if (!want || this.diffLoading || !this.rows.length || this.shownFull !== this.fullFile()) return;
    const state = this.threadState();
    if (!state || (state.at < want.at && !state.error)) return;
    const thread = state.list.find((candidate) => candidate.id === want.id);
    const index = thread?.path === this.path ? this.rows.findIndex((row) => onRow(thread, row)) : -1;
    if (index < 0 && thread?.path === this.path && thread.line != null && !this.fullFile()) {
      this.toggleFullFile();
      return;
    }
    this.focusThread = null;
    this.threadsHidden = false;
    if (want.queue || index < 0) {
      this.queueAt = thread?.id ?? null;
      this.threadsOpen = true;
    } else this.threadsOpen = false;
    if (index >= 0) this.moveCursor(index, cx, "center");
    else cx.notify();
  },

  // The next or previous item of the queue, on its line.
  goToQueue(direction, cx) {
    const { queue, index } = this.queueItem();
    if (!queue.length) return this.notice("No open threads.", cx);
    this.openQueueItem(queue[(index + direction + queue.length) % queue.length], cx);
  },

  openQueueItem(item, cx) {
    this.queueAt = item.id;
    this.threadsOpen = true;
    this.threadsHidden = false;
    const file = item.path == null ? null : this.ahead("branch")?.files.find((f) => f.path === item.path);
    if (!file) return cx.notify();
    if (file.path !== this.path || this.scope !== "branch") return this.pick(file, "branch", cx, { thread: item.id, queue: true });
    this.focusThread = { id: item.id, at: 0, queue: true };
    cx.notify();
  },

  isMarked(row) {
    return this.threadsAt(row).length > 0 || this.findingsAt(row).length > 0;
  },

  // The next or previous thread, finding or comment of ours; past the file's last, the next file that has one,
  // round to the first file after the last, as vim's search wraps.
  jumpThread(direction, cx) {
    const from = this.cursor ?? (direction > 0 ? -1 : this.rows.length);
    for (let i = from + direction; i >= 0 && i < this.rows.length; i += direction)
      if (this.isMarked(this.rows[i])) return this.moveCursor(i, cx, "center");
    const order = this.reviewOrder();
    const at = order.findIndex((e) => e.file.path === this.path && e.scope === this.scope);
    const marked = (entry) =>
      (entry.scope === "branch" && this.fileThreads(entry.file.path).some((thread) => thread.line != null)) ||
      this.fileFindingCount(entry.file.path, entry.scope) > 0;
    for (let step = 1; step <= order.length; step++) {
      const index = (((at + direction * step) % order.length) + order.length) % order.length;
      const entry = order[index];
      if (!marked(entry)) continue;
      const wrapped = direction > 0 ? index <= at : index >= at;
      if (wrapped) this.notice(direction > 0 ? "Back to the first one." : "Round to the last one.", cx);
      if (index !== at) return this.pick(entry.file, entry.scope, cx, { mark: direction > 0 ? "first" : "last" });
      const rows = this.rows.map((row, i) => (this.isMarked(row) ? i : -1)).filter((i) => i >= 0);
      if (rows.length) return this.moveCursor(direction > 0 ? rows[0] : rows[rows.length - 1], cx, "center");
      break;
    }
    this.notice("No threads, findings or comments on this diff's lines.", cx);
  },

  // A file opened by cn or cN starts on its first or last thread or finding; any other on its
  // first change, so the cursor shows from the start.
  revealMark(cx) {
    if (this.diffLoading || !this.rows.length) return;
    if (!this.pendingMark) {
      if (this.cursor == null && !this.focusThread && this.cursorFor !== this.selection) {
        this.cursorFor = this.selection;
        const first = this.rows.findIndex((row) => row.kind === "+" || row.kind === "-");
        this.moveCursor(first >= 0 ? first : 0, cx, "center");
      }
      return;
    }
    const marked = this.rows.map((row, i) => (this.isMarked(row) ? i : -1)).filter((i) => i >= 0);
    const index = this.pendingMark === "first" ? marked[0] : marked[marked.length - 1];
    this.pendingMark = null;
    if (index != null) this.moveCursor(index, cx, "center");
  },

  toggleThreadList(cx) {
    const { item } = this.queueItem();
    if (!this.threadsOpen && item) return this.openQueueItem(item, cx);
    this.threadsOpen = !this.threadsOpen;
    this.threadsHidden = false;
    cx.notify();
  },

  toggleThreadPanel(cx) {
    this.threadsHidden = !this.threadsHidden;
    cx.notify();
  },

  // The merge request's queue, as the sidebar counts it; a click hides or shows the panel.
  ThreadsButton() {
    if (this.scope !== "branch" || !this.branchRequest()) return null;
    const t = theme();
    const queue = this.reviewQueue();
    const open = queue.filter((item) => item.waitingOn === "me").length;
    const waiting = queue.length - open;
    return BarButton({
      id: "threads-toggle",
      icon: this.threadsHidden ? "eye-off" : "eye",
      active: !this.threadsHidden,
      tooltip: `Open threads on !${this.branchRequest().iid} · click to ${this.threadsHidden ? "show" : "hide"} the thread panel`,
      onClick: (cx) => this.toggleThreadPanel(cx),
      children: [
        div().child("Threads"),
        h_flex().gap(3).items_center().text_color(open ? t.ansi5 : t.dim)
          .child(Icon("circle-dot", 13)).child(`${open} open`),
        waiting > 0 &&
          h_flex().gap(3).items_center().text_color(t.dim)
            .child(Icon("clock", 13)).child(`${waiting} waiting on them`),
      ].filter(Boolean),
    });
  },

  startReply(thread, cx) {
    this.replyTo = thread.id;
    this.threadError = null;
    this.replyInput.set_value("");
    this.replyInput.focus();
    cx.notify();
  },

  cancelReply(cx) {
    this.replyTo = null;
    this.replyInput.set_value("");
    this.diffFocus.focus();
    cx.notify();
  },

  // A write to GitLab, then a fresh read so the panel shows what GitLab now has.
  changeThread(write, cx) {
    const mr = this.branchRequest();
    if (!mr || this.threadBusy) return;
    this.threadBusy = true;
    this.threadError = null;
    cx.notify();
    cx.spawn(async (cx) => {
      try {
        await write(mr);
        this.replyTo = null;
        this.replyInput.set_value("");
        this.diffFocus.focus();
      } catch (e) {
        this.threadError = e.message;
      } finally {
        this.threadBusy = false;
        this.refreshThreads(cx, true);
        cx.notify();
      }
    });
  },

  sendReply(thread, cx) {
    const body = this.replyInput.value().trim();
    if (!body) return;
    this.changeThread(async (mr) => {
      await replyToThread(mr, thread, body);
      settleInbox(mr, thread.id, "replied");
    }, cx);
  },

  setResolved(thread, resolved, cx) {
    if (this.threadBusy) return;
    if (resolved) this.settleLocally(thread, { resolved });
    this.changeThread(async (mr) => {
      await resolveThread(mr, thread, resolved);
      if (resolved) settleInbox(mr, thread.id, "dismissed");
      if (resolved) this.hideInSidebar(thread);
    }, cx);
  },

  activity(thread) {
    return (shared(ACTIVITY) ?? {})[thread.id] ?? {};
  },

  noteActivity(id, change) {
    const all = shared(ACTIVITY) ?? {};
    setShared(ACTIVITY, { ...all, [id]: { ...all[id], ...change } });
  },

  // The file the agent reports into, in the repository's git folder.
  async threadNotesFile() {
    if (this.notesFileFor?.root !== this.root) {
      const result = await exec("git", ["rev-parse", "--absolute-git-dir"], { cwd: this.root });
      if (result.code !== 0) throw new Error("Not a git repository");
      this.notesFileFor = { root: this.root, file: `${result.stdout.trim()}/better-changes-threads.jsonl` };
    }
    return this.notesFileFor.file;
  },

  // The thread straight to the agent to fix, with how to tell this card what came of it.
  fixWithAgent(thread, cx) {
    cx.spawn(async (cx) => {
      try {
        const file = await this.threadNotesFile();
        const note = `${THREAD_NOTE} ${quote(file)} ${thread.id}`;
        const report = [
          "When you're done with this one, report it here, and leave GitLab alone:",
          `- \`${note} --fixed <commit>\` once a commit fixes it,`,
          `- \`${note} --already-fixed <commit>\` if a commit already did,`,
          `- \`${note} --not-fixed "<one line why>"\` if it shouldn't or can't be fixed.`,
        ].join("\n");
        this.deliverToAgent(
          [{ ...this.threadComment(thread), report }],
          cx,
          () => this.noteActivity(thread.id, { sent: Date.now(), result: null }),
          (error) => (this.threadError = error),
        );
      } catch (e) {
        this.threadError = e.message;
        cx.notify();
      }
    });
  },

  // What agents reported, onto the activity of their threads.
  pollThreadNotes(cx) {
    if (!this.root || this.notesReading || Date.now() - (this.notesReadAt ?? 0) < NOTES_POLL_MS) return;
    this.notesReading = true;
    this.notesReadAt = Date.now();
    cx.spawn(async (cx) => {
      try {
        const text = await readTextFile(await this.threadNotesFile());
        if (!text || text === this.notesText) return;
        this.notesText = text;
        const all = shared(ACTIVITY) ?? {};
        const fresh = Object.entries(threadResults(text)).filter(([id, result]) => result.at > (all[id]?.sent ?? 0) && all[id]?.result?.at !== result.at);
        if (!fresh.length) return;
        setShared(ACTIVITY, { ...all, ...Object.fromEntries(fresh.map(([id, result]) => [id, { ...all[id], result }])) });
        cx.notify();
      } catch {
        // No notes yet, or not a repository: nothing to show.
      } finally {
        this.notesReading = false;
      }
    });
  },

  // What the agent made of it on the thread, then resolved.
  replyResult(thread, cx) {
    const { result } = this.activity(thread);
    if (!result || this.threadBusy) return;
    const { queue, index } = this.queueItem();
    const next = queue[index + 1] ?? queue[index - 1];
    const reply = resultReply(result);
    this.settleLocally(thread, { reply, resolved: true });
    this.changeThread(async (mr) => {
      await replyToThread(mr, thread, reply);
      if (thread.resolvable) await resolveThread(mr, thread, true);
      settleInbox(mr, thread.id, "dismissed");
      this.hideInSidebar(thread);
    }, cx);
    if (this.threadsOpen && next) this.openQueueItem(next, cx);
  },

  // When it went to the agent and was asked about, and what the agent made of it.
  renderActivity(thread) {
    const t = theme();
    const { sent, asked, result } = this.activity(thread);
    const parts = [sent && `Sent to agent ${clock(sent)}`, asked && `Asked AI ${clock(asked)}`].filter(Boolean);
    const line = parts.length
      ? div().text_size(TEXT.caption).text_color(t.dim).child(parts.join(" · "))
      : null;
    if (!result) return line ? [line] : [];
    const fixed = result.kind !== "not-fixed";
    const box = h_flex()
      .gap(8)
      .items_center()
      .p(8)
      .rounded(8)
      .bg(`${fixed ? t.ansi2 : t.ansi3}18`)
      .border_1()
      .border_color(`${fixed ? t.ansi2 : t.ansi3}55`)
      .child(Icon(fixed ? "check" : "circle-dot", 13).text_color(fixed ? t.ansi2 : t.ansi3))
      .child(
        div()
          .flex_1()
          .min_w(0)
          .text_size(TEXT.small)
          .text_color(t.foreground)
          .child(
            fixed
              ? `Agent: ${result.kind === "fixed" ? "fixed" : "already fixed"} in ${result.commit} · ${clock(result.at)}`
              : `Agent didn't fix it: ${result.reason} · ${clock(result.at)}`,
          ),
      )
      .child(
        PillButton({
          id: `thread-result-${thread.id}`,
          icon: "check",
          label: "Reply & resolve",
          hint: "x",
          tone: "success",
          tooltip: `Posts "${resultReply(result)}" and resolves the thread`,
          onClick: (cx) => this.replyResult(thread, cx),
        }),
      );
    return [line, box].filter(Boolean);
  },

  // The thread as a review comment, on its line when the diff has it.
  threadComment(thread) {
    const at = thread.line == null ? null : this.rows.find((row) => onRow(thread, row));
    const rows = at ? [{ kind: at.kind, old: at.old, next: at.next, text: at.text }] : [];
    const [first, ...replies] = thread.notes;
    const note = [
      `**${first.name || first.author}** on the merge request:`,
      visibleMarkdown(first.body),
      ...replies.map((reply) => `**↳ ${reply.name || reply.author}:** ${visibleMarkdown(reply.body)}`),
    ].join("\n\n");
    return {
      path: thread.path ?? this.path,
      scope: this.scope,
      lines: thread.line == null ? "" : String(thread.line),
      rows,
      note,
      thread: thread.id,
    };
  },

  // With t, the merge request's queue one card at a time; else the threads under the cursor.
  renderThreads() {
    if (this.scope !== "branch" || !this.branchRequest() || this.threadsHidden) return null;
    if (this.threadsOpen) return this.renderQueue();
    const shown = this.threadsAt(this.rows[this.cursor]);
    if (!shown.length && !this.threadError) return null;
    const t = theme();
    const panel = this.threadPanel();
    if (this.threadError) panel.child(div().text_size(TEXT.small).text_color(t.ansi1).child(this.threadError));
    panel.children(shown.map((thread) => this.renderThread(thread)));
    return v_flex()
      .border_b(1)
      .border_color(t.border)
      .child(this.threadHeader("Thread on this line", TextButton({ id: "threads-queue", label: "Queue", onClick: (cx) => this.toggleThreadList(cx) })))
      .child(panel);
  },

  queueItem() {
    const queue = this.reviewQueue();
    const index = Math.max(0, queue.findIndex((item) => item.id === this.queueAt));
    return { queue, index, item: queue[index] ?? null };
  },

  renderQueue() {
    const t = theme();
    const state = this.threadState();
    const { queue, index, item } = this.queueItem();
    const panel = this.threadPanel();
    const error = this.threadError ?? state?.error;
    if (error) panel.child(div().text_size(TEXT.small).text_color(t.ansi1).child(error));
    if (!item) panel.child(state ? this.queueDone() : div().text_size(TEXT.body).text_color(t.dim).child("Reading the threads…"));
    else panel.child(this.renderCard(item, index, queue.length));
    const mine = queue.filter((each) => each.waitingOn === "me").length;
    const count = !queue.length
      ? null
      : div()
          .text_size(TEXT.caption)
          .text_color(t.muted)
          .child(mine ? `${mine} waiting on you` : `${queue.length} waiting on them`);
    return v_flex()
      .border_b(1)
      .border_color(t.border)
      .child(this.threadHeader(`Review queue`, count, "message"))
      .child(panel);
  },

  // Nothing left on the request: said once, plainly, with where it's from.
  queueDone() {
    const t = theme();
    return h_flex()
      .gap(10)
      .items_center()
      .py(6)
      .child(Icon("check", 16).text_color(t.ansi2))
      .child(
        v_flex()
          .gap(2)
          .child(div().text_size(TEXT.body).text_color(t.foreground).font_medium().child("All caught up"))
          .child(div().text_size(TEXT.small).text_color(t.dim).child(`No open threads on !${this.branchRequest().iid}`)),
      );
  },

  threadHeader(title, extra, icon) {
    const t = theme();
    const mr = this.branchRequest();
    return h_flex()
      .px(10)
      .h(SIZE.paneHeader + 2)
      .gap(8)
      .items_center()
      .when(Boolean(icon), (el) => el.child(Icon(icon, 14).text_color(t.muted)))
      .child(
        h_flex()
          .flex_1()
          .min_w(0)
          .gap(6)
          .items_center()
          .child(div().text_size(TEXT.body).text_color(t.foreground).font_medium().child(title))
          .when(Boolean(mr), (el) => el.child(div().text_size(TEXT.small).text_color(t.ansi4).child(`!${mr.iid}`))),
      )
      .when(Boolean(extra), (el) => el.child(extra))
      .child(TextButton({ id: "threads-hide", label: "Hide", onClick: (cx) => this.toggleThreadPanel(cx) }));
  },

  threadPanel() {
    return v_flex().id("thread-panel").max_h(360).overflow_y_scroll().px(10).pb(10).gap(12);
  },

  // A thread's file and line; one the branch no longer changes, or a line the whole file
  // doesn't have, is said to be outside the diff.
  where(thread) {
    if (thread.path == null) return "On the merge request";
    const at = thread.line == null ? thread.path : `${thread.path}:${thread.line}`;
    const inBranch = this.ahead("branch")?.files.some((f) => f.path === thread.path);
    const lost =
      thread.path === this.path && thread.line != null && this.fullFile() && this.shownFull && !this.rows.some((row) => onRow(thread, row));
    return inBranch && !lost ? at : `${at} · not in this diff`;
  },

  // Resolved on GitLab, or for a comment that can't be, dismissed here; then the next item.
  // With what the agent made of it, x posts that first; the Resolve button never posts.
  settleFromQueue(item, cx, quiet = false) {
    if (!quiet && this.activity(item).result) return this.replyResult(item, cx);
    const { queue, index } = this.queueItem();
    const next = queue[index + 1] ?? queue[index - 1];
    if (item.resolvable) this.setResolved(item, true, cx);
    else {
      this.hideInSidebar(item);
      const mr = this.branchRequest();
      if (mr) settleInbox(mr, item.id, "dismissed");
    }
    if (next) this.openQueueItem(next, cx);
    else cx.notify();
  },

  renderCard(item, index, total) {
    const t = theme();
    const mine = item.waitingOn === "me";
    const header = h_flex()
      .gap(8)
      .items_center()
      .text_size(TEXT.small)
      .text_color(t.muted)
      .child(
        h_flex()
          .flex_none()
          .gap(4)
          .px(7)
          .h(20)
          .items_center()
          .rounded(10)
          .text_size(TEXT.caption)
          .font_medium()
          .bg(`${mine ? t.ansi5 : t.dim}22`)
          .text_color(mine ? t.ansi5 : t.dim)
          .child(Icon(mine ? "circle-dot" : "clock", 12))
          .child(mine ? "Open" : "Waiting on them"),
      )
      .child(
        div()
          .id("queue-where")
          .flex_1()
          .min_w(0)
          .truncate()
          .cursor_pointer()
          .hover((s) => s.text_color(t.foreground))
          .tooltip("Go to the line")
          .on_click((_e, cx) => this.openQueueItem(item, cx))
          .child(this.where(item)),
      )
      .child(div().flex_none().text_color(t.dim).child(`${index + 1} / ${total}`))
      .child(IconButton({ id: "queue-prev", icon: "chevron-left", label: "Previous (cN)", small: true, onClick: (cx) => this.goToQueue(-1, cx) }))
      .child(IconButton({ id: "queue-next", icon: "chevron-right", label: "Next (cn)", small: true, onClick: (cx) => this.goToQueue(1, cx) }));
    const card = v_flex()
      .gap(8)
      .pl(10)
      .border_l(2)
      .border_color(mine ? t.ansi5 : t.dim)
      .child(header)
      .child(this.threadActions(item, true))
      .children(this.renderActivity(item))
      .children(this.renderNotes(item))
      .children(this.renderAnswers(item));
    return this.withReplyBox(card, item);
  },

  // Fix, resolve, ask and reply; in the queue, resolving moves on to the next item.
  threadActions(thread, inQueue = false) {
    const id = (name) => `thread-${name}-${thread.id}`;
    const sent = Boolean(this.activity(thread).sent);
    return h_flex()
      .gap(6)
      .flex_wrap()
      .child(
        PillButton({
          id: id("fix"),
          icon: sent ? "check" : "send",
          label: this.sendingComments ? "Sending…" : sent ? "Sent to agent" : "Fix with agent",
          hint: inQueue && "F",
          tone: sent ? null : "primary",
          tooltip: "Send this thread to the branch's agent to fix",
          onClick: (cx) => this.fixWithAgent(thread, cx),
        }),
      )
      .when(inQueue && !thread.resolvable, (el) =>
        el.child(
          PillButton({ id: id("dismiss"), icon: "close", label: "Dismiss", hint: "x", tooltip: "Hide it here until someone writes on it again", onClick: (cx) => this.settleFromQueue(thread, cx) }),
        ),
      )
      .when(thread.resolvable, (el) =>
        el.child(
          PillButton({
            id: id("resolve"),
            icon: thread.resolved ? "refresh" : "check",
            label: thread.resolved ? "Reopen" : "Resolve",
            hint: inQueue && !this.activity(thread).result && "x",
            tone: thread.resolved || this.activity(thread).result ? null : "success",
            tooltip: this.activity(thread).result ? "Resolves without a reply" : null,
            onClick: (cx) => (inQueue ? this.settleFromQueue(thread, cx, true) : this.setResolved(thread, !thread.resolved, cx)),
          }),
        ),
      )
      .child(PillButton({ id: id("ask"), icon: "sparkles", label: "Ask AI", hint: inQueue && "a", onClick: (cx) => this.askThread(thread, cx) }))
      .child(PillButton({ id: id("reply"), icon: "message", label: "Reply", hint: "r", onClick: (cx) => this.startReply(thread, cx) }));
  },

  renderAnswers(thread) {
    const t = theme();
    return this.threadAnswers(thread).map((answer) =>
      v_flex()
        .gap(4)
        .p(8)
        .rounded(8)
        .bg(t.background)
        .border_1()
        .border_color(t.border)
        .child(
          h_flex()
            .gap(4)
            .items_center()
            .text_size(TEXT.caption)
            .text_color(t.accent)
            .child(Icon("sparkles", 12))
            .child(answer.status === "done" ? "Claude" : "Asking Claude…"),
        )
        .when(answer.status === "done", (el) => el.child(Markdown(`thread-answer-${answer.id}`, answer.answer || " "))),
    );
  },

  // The finding clamped until asked for, the replies between folded, the latest whole.
  renderNotes(thread) {
    const t = theme();
    const [first, ...replies] = thread.notes;
    const latest = replies.length ? replies[replies.length - 1] : null;
    const between = replies.slice(0, -1);
    const whole = this.notesOpen?.has(thread.id);
    const clipped = excerpt(first.body, CLAMP_LINES);
    const note = (n, i, text) =>
      v_flex()
        .gap(3)
        .child(div().text_size(TEXT.small).font_semibold().text_color(t.foreground).child(n.name))
        .child(Markdown(`thread-${thread.id}-${i}`, text || " ", TEXT.body));
    const toggle = (label) =>
      div().child(TextButton({ id: `thread-more-${thread.id}`, label, onClick: (cx) => this.toggleNotes(thread, cx) }));
    return [
      note(first, 0, whole ? visibleMarkdown(first.body) : clipped.text),
      clipped.clipped || between.length
        ? toggle(whole ? "Show less" : [clipped.clipped && "Show all", between.length && `${between.length} earlier repl${between.length === 1 ? "y" : "ies"}`].filter(Boolean).join(" · "))
        : null,
      ...(whole ? between.map((n, i) => note(n, i + 1, visibleMarkdown(n.body))) : []),
      latest ? note(latest, replies.length, visibleMarkdown(latest.body)) : null,
    ].filter(Boolean);
  },

  toggleNotes(thread, cx) {
    this.notesOpen ??= new Set();
    if (this.notesOpen.has(thread.id)) this.notesOpen.delete(thread.id);
    else this.notesOpen.add(thread.id);
    cx.notify();
  },

  renderThread(thread) {
    const t = theme();
    const card = v_flex()
      .gap(8)
      .pl(10)
      .border_l(2)
      .border_color(thread.resolved ? t.dim : t.ansi5)
      .child(
        h_flex()
          .gap(6)
          .items_center()
          .text_size(TEXT.small)
          .text_color(t.dim)
          .when(thread.resolvable, (el) =>
            el.child(
              h_flex()
                .flex_none()
                .gap(4)
                .px(7)
                .h(20)
                .items_center()
                .rounded(10)
                .text_size(TEXT.caption)
                .font_medium()
                .bg(`${thread.resolved ? t.ansi2 : t.ansi5}22`)
                .text_color(thread.resolved ? t.ansi2 : t.ansi5)
                .child(Icon(thread.resolved ? "circle-check" : "circle-dot", 12))
                .child(thread.resolved ? "Resolved" : "Open"),
            ),
          )
          .child(div().flex_1().min_w(0).truncate().child(this.where(thread))),
      )
      .child(this.threadActions(thread))
      .children(this.renderActivity(thread))
      .children(this.renderNotes(thread))
      .children(this.renderAnswers(thread));
    return this.withReplyBox(card, thread);
  },

  withReplyBox(card, thread) {
    if (this.replyTo !== thread.id) return card;
    return card.child(
      v_flex()
        .id(`thread-reply-box-${thread.id}`)
        .gap(4)
        .on_key_down((e, cx) => {
          this.keyFromBox = true;
          if (e.keystroke === "cmd-enter") this.sendReply(thread, cx);
          if (e.keystroke === "escape") this.cancelReply(cx);
        })
        .child(TextBox({ id: "thread-reply", state: this.replyInput, focused: true, label: "Reply", height: 56 }))
        .child(
          h_flex()
            .gap(6)
            .child(
              TextButton({
                id: "thread-reply-send",
                label: this.threadBusy ? "Sending…" : "Reply on GitLab ⌘↩",
                active: true,
                onClick: (cx) => this.sendReply(thread, cx),
              }),
            )
            .child(TextButton({ id: "thread-reply-cancel", label: "Cancel", onClick: (cx) => this.cancelReply(cx) })),
        ),
    );
  },
};
