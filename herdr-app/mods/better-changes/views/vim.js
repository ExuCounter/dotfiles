// Vim keys in the diff tab: a line cursor moved with j/k, gg/G, ctrl-d/ctrl-u and ]c/[c,
// shift-v to pick lines from it, and c or enter to comment on them. The cursor is an index
// into this.rows, the inline rows, whichever layout is drawn.
const HALF_PAGE = 20;
const CHORD_MS = 800;

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

  // Keys typed into the comment box reach this handler too, so it stays out of their way.
  vimKey(event, cx) {
    if (this.typingComment || this.conflictCount) return false;
    const key = event.keystroke;
    const chord = this.chord && Date.now() - this.chord.at < CHORD_MS ? this.chord.key : null;
    this.chord = null;
    if (chord === "g" && key === "g") this.moveCursor(0, cx, "top");
    else if (chord === "]" && key === "c") this.jumpChange(1, cx);
    else if (chord === "[" && key === "c") this.jumpChange(-1, cx);
    else if (["g", "]", "["].includes(key)) this.chord = { key, at: Date.now() };
    else if (key === "j" || key === "down") this.step(1, cx);
    else if (key === "k" || key === "up") this.step(-1, cx);
    else if (key === "shift-g" || key === "G") this.moveCursor(this.rows.length, cx, "top");
    else if (key === "ctrl-d") this.step(HALF_PAGE, cx, "center");
    else if (key === "ctrl-u") this.step(-HALF_PAGE, cx, "center");
    else if (key === "shift-v" || key === "V") this.startVisual(cx);
    else if ((key === "c" || key === "enter") && this.commentable()) this.openComment(cx);
    else if (key === "escape" && this.picked) {
      this.visual = false;
      this.cancelComment(cx);
    } else return false;
    return true;
  },
};
