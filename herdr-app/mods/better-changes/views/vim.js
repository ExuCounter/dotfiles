// Vim keys in the diff tab: a line cursor moved with j/k, gg/G, ctrl-d/ctrl-u, ] and [
// (changes) and cn/cN (merge request threads), shift-v to pick lines from it, c or enter to
// comment on them, a to ask Claude about them, shift-r for Claude's review, r to reply to the
// thread on the line, t to list the file's threads and shift-t to hide them. The cursor
// is an index into this.rows, the inline rows, whichever layout is drawn.
import { focused } from "herdr";

const HALF_PAGE = 20;
const CHORD_MS = 800;
// A c waits this long for an n or N before it opens the comment box.
const COMMENT_CHORD_MS = 350;

const isLine = (row) => ["+", "-", " "].includes(row?.kind);
const isChange = (row) => row?.kind === "+" || row?.kind === "-";

export const vimMethods = {
  // Which drawn row holds an inline row: itself inline, its pair side by side.
  drawnIndex(index) {
    const row = this.rows[index];
    if (this.diffLayout !== "split") return index;
    return (this.pairedRows ?? []).findIndex((p) => p === row || p.left === row || p.right === row);
  },

  isCursor(row) {
    return row != null && this.cursor != null && this.rows[this.cursor] === row;
  },

  moveCursor(index, cx, strategy) {
    const lines = this.rows.map((row, i) => (isLine(row) ? i : -1)).filter((i) => i >= 0);
    if (!lines.length) return;
    const clamped = Math.max(lines[0], Math.min(lines[lines.length - 1], index));
    // Land on a line, skipping hunk headers in the way of the move.
    const forward = this.cursor == null || clamped >= this.cursor;
    const target = forward
      ? (lines.find((i) => i >= clamped) ?? lines[lines.length - 1])
      : ([...lines].reverse().find((i) => i <= clamped) ?? lines[0]);
    this.cursor = target;
    if (this.picked && this.visual) this.picked = { ...this.picked, end: target };
    const drawn = this.drawnIndex(target);
    if (drawn >= 0) this.diffScroll.scroll_to_item(drawn, strategy);
    cx.notify();
  },

  step(lines, cx, strategy) {
    if (this.cursor == null) return this.moveCursor(0, cx);
    let index = this.cursor;
    const direction = Math.sign(lines);
    for (let left = Math.abs(lines); left > 0; ) {
      index += direction;
      if (index < 0 || index >= this.rows.length) break;
      if (isLine(this.rows[index])) left--;
    }
    this.moveCursor(index, cx, strategy);
  },

  // The first line of the next or previous run of added or removed lines.
  jumpChange(direction, cx) {
    const from = this.cursor ?? (direction > 0 ? -1 : this.rows.length);
    for (let i = from + direction; i >= 0 && i < this.rows.length; i += direction) {
      if (isChange(this.rows[i]) && !isChange(this.rows[i - 1])) return this.moveCursor(i, cx, "center");
    }
  },

  startVisual(cx) {
    if (this.cursor == null) this.moveCursor(0, cx);
    if (this.cursor == null) return;
    this.visual = true;
    this.picked = { start: this.cursor, end: this.cursor };
    cx.notify();
  },

  openComment(cx) {
    if (this.cursor == null && !this.picked) return;
    if (!this.picked) this.picked = { start: this.cursor, end: this.cursor };
    this.visual = false;
    this.commentInput.focus();
    cx.notify();
  },

  // Coming to the diff's pane, from another tab or a pane beside it, focuses the pane, not the
  // diff in it; the keys need the diff.
  focusOnArrival() {
    const tab = this.diffTab();
    const now = focused();
    // A mod pane isn't always named as the focused pane; a terminal is, so on this tab with no
    // terminal focused, the diff's pane is the one.
    const here = Boolean(tab) && now?.tab === tab && !now.terminal;
    if (here && !this.onTab && !this.picked && !this.replyTo) this.diffFocus?.focus();
    this.onTab = here;
  },

  // Keys typed into a text box reach this handler too, so it stays out of their way. Only an
  // open box can be typed in: a focus event missed when one closed doesn't hold the keys.
  typing() {
    const boxOpen = Boolean((this.picked && !this.visual) || this.replyTo);
    return Boolean(this.typingComment) && boxOpen && !this.diffFocus?.is_focused();
  },

  vimKey(event, cx) {
    if (this.typing() || this.conflictCount) return false;
    const key = event.keystroke;
    if (key === "?" || key === "shift-/") {
      this.toggleHelp(cx);
      return true;
    }
    if (this.helpOpen && key === "escape") {
      this.toggleHelp(cx);
      return true;
    }
    const chord = this.chord && Date.now() - this.chord.at < CHORD_MS ? this.chord.key : null;
    this.chord = null;
    if (chord === "g" && key === "g") this.moveCursor(0, cx, "top");
    else if (chord === "c" && key === "n") this.threadsOpen ? this.goToQueue(1, cx) : this.jumpThread(1, cx);
    else if (chord === "c" && (key === "shift-n" || key === "N")) this.threadsOpen ? this.goToQueue(-1, cx) : this.jumpThread(-1, cx);
    else if (key === "]") this.jumpChange(1, cx);
    else if (key === "[") this.jumpChange(-1, cx);
    else if (key === "t" && this.branchRequest() && this.scope === "branch") this.toggleThreadList(cx);
    else if ((key === "shift-t" || key === "T") && this.branchRequest() && this.scope === "branch")
      this.toggleThreadPanel(cx);
    else if (key === "shift-r" || key === "R") this.toggleReview(cx);
    else if (this.threadsOpen && this.queueItem().item && ["r", "x", "a", "shift-f", "F"].includes(key)) {
      const { item } = this.queueItem();
      if (key === "r") this.startReply(item, cx);
      else if (key === "x") this.settleFromQueue(item, cx);
      else if (key === "a") this.askThread(item, cx);
      else if (key === "shift-f" || key === "F") this.fixWithAgent(item, cx);
    } else if (key === "a" && this.commentable()) this.startAsk(cx);
    else if (key === "r" && this.threadsAt(this.rows[this.cursor]).length)
      this.startReply(this.threadsAt(this.rows[this.cursor])[0], cx);
    else if (key === "f") {
      this.toggleFullFile();
      cx.notify();
    } else if (key === "g") this.chord = { key, at: Date.now() };
    else if (key === "c" && this.commentable()) {
      const pending = { key, at: Date.now() };
      this.chord = pending;
      cx.timer.after(COMMENT_CHORD_MS, (cx) => {
        if (this.chord !== pending) return;
        this.chord = null;
        this.openComment(cx);
      });
    }
    else if (key === "shift-j" || key === "J") this.stepFile(1, cx);
    else if (key === "shift-k" || key === "K") this.stepFile(-1, cx);
    else if (key === "j" || key === "down") this.step(1, cx);
    else if (key === "k" || key === "up") this.step(-1, cx);
    else if (key === "shift-g" || key === "G") this.moveCursor(this.rows.length, cx, "top");
    else if (key === "ctrl-d") this.step(HALF_PAGE, cx, "center");
    else if (key === "ctrl-u") this.step(-HALF_PAGE, cx, "center");
    else if (key === "shift-v" || key === "V") this.startVisual(cx);
    else if (key === "enter" && this.commentable()) this.openComment(cx);
    else if (key === "escape" && this.threadsOpen) this.toggleThreadList(cx);
    else if (key === "escape" && this.picked) {
      this.visual = false;
      this.cancelComment(cx);
    } else return false;
    return true;
  },
};
