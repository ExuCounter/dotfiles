// Better Changes: a Git sidebar, and the diff tab it opens in the centre. One
// class plays both roles; shared("better-changes.*") connects the copies.
// The class is built from separate files, so a method used here may live in any of:
//   git/repository.js   following the repository, the index, history, commit and amend
//   views/sidebar.js    the tabs, options menu, file groups and commit views
//   views/diff.js       opening a file in the centre tab, reading it, and drawing it
//   views/comments.js   review comments on diff lines, sent to an agent in the space
//   views/review.js     stepping through files with ctrl-j/k and marking them viewed with v
//   views/vim.js        a line cursor and vim motions in the diff
//   views/pane-header.js  the header row above a pane
// git/reads.js reads from Git, git/model.js parses its output, views/ui.js holds every look
// but the token colours: syntax.js colours a diff's code, and Better Files has the same file.
import { View } from "gpui-kit";
import { TextareaState, VirtualListScrollHandle, ScrollHandle } from "gpui-base";
import { props, shared, setShared, nextCommand, layout, run, notify, closeOverlay } from "herdr";
import { loadSettings, duration } from "./settings.js";
import { setCodeSize } from "./views/ui.js";
import { followFileIcons } from "./file-icons.js";
import { panelCommands } from "./panel.js";
import { gitMethods } from "./git/repository.js";
import { sidebarMethods } from "./views/sidebar.js";
import { diffMethods } from "./views/diff.js";
import { commentMethods } from "./views/comments.js";
import { reviewMethods } from "./views/review.js";
import { vimMethods } from "./views/vim.js";
import { threadMethods } from "./views/threads.js";
import { helpMethods } from "./views/help.js";
import { reviewerMethods } from "./views/reviewer.js";
import { paneHeaderMethods } from "./views/pane-header.js";

const CONTEXT_POLL_MS = 300;
const STATUS_POLL_MS = 10000;
// Preferences a person may change in the installed mod.json under `settings`.
const DEFAULT_SETTINGS = {
  refresh: { status: "10s" },
  limits: { files: 1000, diff_lines: 1500, line_length: 4000, commits_per_page: 50 },
  default: { view: "tree", diff: "inline" },
  panel: { toggle: false },
  font_size: 0,
  context_lines: 3,
};

class BetterChanges extends View {
  init(given, cx) {
    const p = props() ?? given ?? {};
    // Herdr hands a pane header its pane. One copy runs per pane, so it reads no Git.
    if (p.pane) {
      this.mode = "pane-header";
      this.hovered = false;
      return;
    }
    if (p.overlay) {
      this.mode = "panel-key";
      this.runPanelKey(p.overlay, cx);
      return;
    }
    this.mode = p.mode ?? "sidebar";
    this.diffSpace = p.space;
    this.source = p.source;
    this.settings = DEFAULT_SETTINGS;
    this.restoreDiffSelection(p);
    // Better Tabs draws this on the diff tab.
    setShared("mod-icons", {
      ...(shared("mod-icons") ?? {}),
      "better-changes": "mods/better-changes/icons/file.svg",
    });
    followFileIcons(this, cx);
    if (!shared("better-changes.viewed")) this.loadViewed();

    this.tab = localStorage.getItem("tab") === "commit" ? "commit" : "changes";
    this.view = localStorage.getItem("view") === "flat" ? "flat" : "tree";
    this.diffLayout =
      shared("better-changes.diff-layout") ??
      (localStorage.getItem("diff-layout") === "split" ? "split" : "inline");
    if (this.mode === "sidebar") setShared("better-changes.diff-layout", this.diffLayout);
    this.menuOpen = false;
    this.menuFocus = cx.focus_handle();
    this.closed = new Set();
    this.collapsed = new Set(JSON.parse(localStorage.getItem("collapsed") ?? "[]"));
    this.files = [];
    this.rows = [];
    this.splitOffset = 0;
    this.diffToken = 0;
    this.resetCommits();
    if (this.mode === "sidebar") {
      this.initCommitBox(cx);
      this.changesScroll = ScrollHandle.new();
    }
    if (this.mode === "diff") {
      this.commentInput = TextareaState.new({ placeholder: "What should change here?", rows: 3 });
      this.diffFocus = cx.focus_handle();
      this.diffScroll = VirtualListScrollHandle.new();
      this.commentInput.on("focus", () => {
        this.typingComment = true;
      });
      this.commentInput.on("blur", () => {
        this.typingComment = false;
      });
      this.replyInput = TextareaState.new({ placeholder: "Reply on GitLab", rows: 2 });
      this.replyInput.on("focus", () => {
        this.typingComment = true;
      });
      this.replyInput.on("blur", () => {
        this.typingComment = false;
      });
    }

    cx.timer.every(CONTEXT_POLL_MS, (cx) => this.follow(cx));
    this.applySettings(cx);
    cx.spawn(async (cx) => {
      for (;;) this.command(await nextCommand(), cx);
    });
    this.refresh(cx);
  }

  // `mod.open:better-changes` from a key. `<mod>.<command>` can't reach a hidden
  // panel, so a copy opens as an overlay for a moment and acts on the layout.
  runPanelKey(overlay, cx) {
    cx.spawn(async () => {
      try {
        const { settings } = await loadSettings("better-changes", DEFAULT_SETTINGS);
        const commands = panelCommands(layout(), "better-changes", settings.panel.toggle);
        if (commands) for (const [name, args] of commands) run(name, args);
        else notify({ title: "Better Changes isn't in this layout" });
      } finally {
        closeOverlay(overlay);
      }
    });
  }

  initCommitBox(cx) {
    this.message = "";
    this.messageRevision = 0;
    this.commitMode = "commit";
    this.commitMenuOpen = false;
    this.commitMenuFocus = cx.focus_handle();
    this.amendToken = 0;
    this.amendLoading = false;
    this.amendHead = null;
    this.typing = false;
    // Enter makes a new line here; only the button commits.
    this.input = TextareaState.new({ placeholder: "Commit message", rows: 4 });
    this.input.on("change", (_e, cx) => {
      this.message = this.input.value();
      this.messageRevision++;
      cx.notify();
    });
    this.input.on("focus", (_e, cx) => {
      this.typing = true;
      cx.notify();
    });
    this.input.on("blur", (_e, cx) => {
      this.typing = false;
      cx.notify();
    });
  }

  // Read the installed mod.json once, then start the status poll at its pace.
  // The view and diff defaults apply only where nothing was chosen before.
  applySettings(cx) {
    cx.spawn(async (cx) => {
      const { settings, problems } = await loadSettings("better-changes", DEFAULT_SETTINGS);
      for (const problem of problems) console.warn(`better-changes mod.json settings: ${problem}`);
      // A limit of zero would empty the panel, so it falls back like a bad value.
      for (const key of Object.keys(settings.limits))
        if (!(settings.limits[key] > 0)) settings.limits[key] = DEFAULT_SETTINGS.limits[key];
      this.settings = settings;
      setCodeSize(settings.font_size);
      if (localStorage.getItem("view") === null && ["tree", "flat"].includes(settings.default.view))
        this.view = settings.default.view;
      if (
        this.mode === "sidebar" &&
        localStorage.getItem("diff-layout") === null &&
        ["inline", "split"].includes(settings.default.diff)
      ) {
        this.diffLayout = settings.default.diff;
        setShared("better-changes.diff-layout", this.diffLayout);
      }
      // A floor, so a bare number read as milliseconds cannot spin Git.
      cx.timer.every(Math.max(1000, duration(settings.refresh.status, STATUS_POLL_MS)), (cx) =>
        this.refresh(cx),
      );
      cx.notify();
    });
  }

  // `better-changes.<command>`, for keys.
  command(command, cx) {
    // pane.go (ctrl-h/j/k/l) lands on the diff's pane: the keys go to the diff.
    if (command === "focus" && this.mode === "diff") {
      this.diffFocus.focus();
      this.onTab = true;
      cx.notify();
    }
    // TEMP probe
    if (command?.startsWith?.("probe-") && this.mode === "diff") {
      const before = this.cursor;
      let handled, error;
      try {
        handled = this.vimKey({ keystroke: command.slice(6) }, cx);
      } catch (err) {
        error = String(err?.stack ?? err);
      }
      const all = shared("bc.probe") ?? {};
      setShared("bc.probe", { ...all, [this.diffSpace ?? "?"]: { key: command.slice(6), before, after: this.cursor, handled, error, rows: this.rows?.length, kinds: this.rows?.slice(Math.max(0, (before ?? 0) - 2), (before ?? 0) + 4).map((r) => r.kind), loading: this.diffLoading, typing: this.typing(), conflicts: this.conflictCount, layout: this.diffLayout, paired: this.pairedRows?.length, scope: this.scope, path: this.path, truncated: this.truncated, error: this.error, note: this.note } });
    }
    if (command === "refresh") this.refreshAll(cx);
    if (["next-file", "prev-file"].includes(command) && this.reviewsActiveSpace())
      this.stepFile(command === "next-file" ? 1 : -1, cx);
    if (command === "changes" || command === "commit") this.setTab(command, cx);
    if (command === "flat" || command === "tree") this.setView(command, cx);
    if (command === "inline" || command === "split") this.setDiffLayout(command, cx);
    if (command.startsWith("open:")) {
      const file = this.files.find((f) => f.path === command.slice(5));
      if (file)
        this.pick(file, file.conflict ? "conflict" : file.unstaged ? "unstaged" : "staged", cx);
    }
  }

  follow(cx) {
    const style = shared("better-changes.diff-layout");
    if (style && style !== this.diffLayout) {
      this.diffLayout = style;
      localStorage.setItem("diff-layout", style);
      cx.notify();
    }
    if (this.contextKey() !== this.context) this.refresh(cx);
    if (this.mode === "sidebar") {
      this.openRequestedThread(cx);
      this.revealShown(cx);
    }
    if (this.mode === "diff") {
      this.focusOnArrival();
      this.syncSelection(cx);
      this.revealThread(cx);
      this.revealMark(cx);
      this.pollReview(cx);
      this.pollThreadNotes(cx);
      if (this.root && this.path && this.shownFull !== this.fullFile()) this.loadDiff(cx);
      this.publishHead();
    }
    const reload = shared("better-changes.reload");
    if (
      reload &&
      reload.at !== this.reload &&
      reload.root === this.root &&
      reload.on === (this.on ?? null) &&
      !this.loading &&
      !this.busy
    ) {
      this.reload = reload.at;
      this.refresh(cx);
    }
  }
}

Object.assign(
  BetterChanges.prototype,
  gitMethods,
  sidebarMethods,
  diffMethods,
  commentMethods,
  reviewMethods,
  vimMethods,
  threadMethods,
  helpMethods,
  reviewerMethods,
  paneHeaderMethods,
);

export default BetterChanges;
