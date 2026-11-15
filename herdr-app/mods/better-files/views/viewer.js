// A file in the centre pane, read-only, following the file as it changes on disk. Editing
// belongs in the code editor it can open.
import { div, image } from "gpui-kit";
import { h_flex, v_flex, Editor, EditorState, Scrollbar, v_virtual_list } from "gpui-base";
import { appHome, exec, focused, layout, panes, readTextFile, setShared, shared, theme } from "herdr";
import {
  baseName,
  buildRows,
  fileLinesOf,
  hunkKey,
  isImage,
  isMarkdown,
  languageOf,
  markdownBlocks,
  parentOf,
  parseHunks,
  resolvePath,
  viewable,
} from "../files/model.js";
import { WHOLE_FILE_LINES, highlightLines, languageOf as lexerLanguage, syntaxColors, tokenizeLine } from "../syntax.js";
import { viewerEntries } from "../actions/open.js";
import { foundEditors } from "../actions/outside.js";
import { fileIcon, isLight } from "../files/file-icons.js";
import { TEXT, FileIcon, Markdown, Message, MenuButton, TextButton, codeFont, codeSize } from "./ui.js";

const CHAR_WIDTH = 0.62; // Of the code font's size, to size the sideways scroll.
const LINE_COLUMNS = 6; // The number column and a margin, in the same units.
const rowHeight = () => Math.round(codeSize() * 1.45);
const REMOVED_ROW = 8;

// $1 the file, $2 its copy, $3 the copy of what this tab showed before. No file name reaches
// the script itself, and only the cache's own copies are ever removed.
const COPY_IMAGE = `[ -z "$3" ] || rm -f -- "$3"; mkdir -p -- "$(dirname -- "$2")" && { cmp -s -- "$1" "$2" || cp -- "$1" "$2"; }`;

export const viewerMethods = {
  // What this tab shows: the registry, then what it was opened with, after a restart.
  viewerEntry() {
    return viewerEntries()[this.viewerId] ?? null;
  },

  // Runs as the tab opens, which is when the focused tab is its own.
  claimTab() {
    const entry = this.viewerEntry();
    const where = this.tabSpaces();
    const holds = (other) => Boolean(other.tab) && !this.wrongTab(other, where);
    // A tab recorded from another space isn't this one, so it keeps looking for its own.
    if (entry && holds(entry)) return;
    const space = entry?.space ?? this.viewerSpace;
    const tab = focused()?.tab;
    if (!tab || !panes().some((p) => p.tab === tab && p.mod === "better-files")) return;
    // Focus can sit in another space while this tab opens; that space's tab isn't this one.
    if ((where.get(tab) ?? space) !== space) return;
    const rest = Object.entries(viewerEntries()).filter(([id]) => id !== this.viewerId).map(([, other]) => other);
    // A tab reopened behind another one must not take that one's place.
    if (rest.some((other) => holds(other) && other.tab === tab)) return;
    if (entry?.others?.includes(tab)) return;
    // Nor may it take the tab of a viewer here asked for after it, which hasn't claimed one yet.
    const unclaimed = (other) => (other.tab ? !holds(other) : this.viewerIsLive(other));
    const newer = (other) => other.space === space && (other.at ?? 0) > (entry?.at ?? 0) && unclaimed(other);
    if (rest.some((other) => newer(other) && other.others && !other.others.includes(tab))) return;
    // A click skips a viewer while its tab is wrong, so the space may have a new shared tab
    // by now; then this one becomes a tab you keep, leaving one shared tab per space.
    const sharedHere = rest.some(
      (other) => other.space === space && other.preview && this.viewerIsLive(other) && !this.wrongTab(other, where),
    );
    this.setViewer(this.viewerId, {
      tab,
      space,
      file: entry?.file ?? this.viewerFile,
      preview: (entry?.preview ?? false) && !sharedHere,
    });
  },

  syncViewer(cx) {
    this.claimTab();
    const file = this.viewerEntry()?.file ?? this.viewerFile;
    if (!file) return;
    if (file.path !== this.file?.path) {
      this.file = file;
      this.text = undefined;
      this.problem = null;
      this.code?.release();
      this.code = null;
      this.hunks = [];
      this.openHunks = new Set();
      this.readFile(cx);
      this.readHunks(cx);
      cx.notify();
    }
    this.publishHead();
  },

  // Asked on every check, not just when the text changes: a commit clears marks without
  // touching the file.
  readHunks(cx) {
    const file = this.file;
    if (!file || !this.gutterOn || this.diffing || isImage(file.path)) return;
    this.diffing = true;
    cx.spawn(async (cx) => {
      const git = (args) =>
        exec("git", ["--no-optional-locks", ...args], { cwd: file.root, on: file.on }).catch(() => null);
      let marks = [];
      const status = await git(["status", "--porcelain=v1", "--", file.path]);
      if (status?.code === 0 && status.stdout.startsWith("??")) {
        marks = [{ line: 0, count: Infinity, kind: "added", oldStart: 0, old: [] }];
      } else if (status?.code === 0 && status.stdout.trim()) {
        const diff = await git(["diff", "--no-color", "--no-ext-diff", "--no-textconv", "-U0", "HEAD", "--", file.path]);
        if (diff?.code === 0) marks = parseHunks(diff.stdout);
      }
      this.diffing = false;
      if (this.file?.path !== file.path) return;
      if (JSON.stringify(marks) !== JSON.stringify(this.hunks)) {
        this.hunks = marks;
        cx.notify();
      }
    });
  },

  // Only a real change touches the view, so the place you're reading stays put.
  readFile(cx) {
    const file = this.file;
    if (file && isImage(file.path)) return this.readImage(cx);
    if (!file || this.reading) return;
    this.reading = true;
    cx.spawn(async (cx) => {
      let shown;
      try {
        shown = viewable(await readTextFile(file.path, { on: file.on }));
      } catch {
        shown = { problem: "This file can't be shown: it's too large, or can't be read." };
      }
      this.reading = false;
      if (this.file?.path !== file.path) return;
      if (shown.problem) {
        this.problem = shown.problem;
        this.text = undefined;
        this.code?.release();
        this.code = null;
      } else if (shown.text !== this.text) {
        this.problem = null;
        this.text = shown.text;
        if (!this.gutterOn) {
          if (this.code) this.code.set_value(shown.text);
          else this.code = this.newCode(file, shown.text);
        }
      }
      this.readMarkdownImages(cx);
      cx.notify();
    });
  },

  newCode(file, value) {
    const t = theme();
    return EditorState.new({
      language: languageOf(file.path),
      readonly: true,
      value,
      font_family: codeFont(),
      font_size: codeSize(),
      syntax: {
        keyword: t.ansi5,
        string: t.ansi2,
        comment: t.dim,
        function: t.ansi4,
        type: t.ansi3,
        number: t.ansi1,
        constant: t.ansi6,
        boolean: t.ansi6,
        operator: t.ansi6,
        "string.escape": t.ansi6,
      },
    });
  },

  // What the pane's header row says, the same row a diff uses: file, folder, and whether
  // this is the shared tab.
  viewerHead() {
    const file = this.file;
    if (!file) return null;
    const name = baseName(file.path);
    const folder = file.path.slice(file.root.length + 1, -name.length - 1);
    const picture = fileIcon(this.fileIcons, file.path, { light: isLight(theme().background) });
    return {
      title: name,
      detail: [folder, this.viewerEntry()?.preview ? "Preview" : null].filter(Boolean).join(" · "),
      // color: a full-colour picture, which Better Changes' pane header draws untinted.
      ...(picture ? { icon: picture, color: true } : { icon: "mods/better-files/icons/file.svg" }),
    };
  },

  publishHead() {
    // Never onto a tab in another space: that one has its own viewer.
    const entry = this.viewerEntry();
    const tab = entry && !this.wrongTab(entry) ? entry.tab : null;
    const pane = tab && panes().find((p) => p.mod === "better-files" && p.tab === tab)?.pane;
    const head = this.viewerHead();
    if (!pane || !head) return;
    const heads = shared("pane-heads") ?? {};
    if (JSON.stringify(heads[pane]) !== JSON.stringify(head))
      setShared("pane-heads", { ...heads, [pane]: head });
  },

  // Better Changes' pane header shows a published title. With any other header, the file
  // draws its own row, so there's always exactly one.
  headerShowsTitle() {
    const find = (node) =>
      node?.content?.pane?.header?.content?.mod ?? (node?.children ?? []).map(find).find(Boolean);
    return find(layout()) === "better-changes";
  },

  // The file as rows, the way Better Changes draws a diff. Herdr's editor can't mark a line,
  // and marks laid over it slid as it scrolled, but here a line's colour is part of its row.
  linesView() {
    const lines = this.fileLines();
    const runs = this.lineRuns(lines);
    const rows = buildRows(lines, this.hunks ?? [], this.openHunks);
    const height = rowHeight();
    const sized = rows.some((row) => row.type === "removed")
      ? rows.map((row) => (row.type === "removed" ? REMOVED_ROW : height))
      : height;
    const listId = `viewer-lines-${this.viewerId}-${this.file.path}`;
    const list = v_virtual_list(
      listId,
      rows.length,
      sized,
      (i) => rows[i].key,
      (range) => rows.slice(range.start, range.end).map((row) => this.fileRow(row, runs)),
    )
      // A handler per list, not per row: Herdr's virtual lists allow no handlers in a row.
      .on_item_click((key, cx) => this.toggleChange(rows.find((row) => row.key === key), cx))
      .size_full();
    const widest = lines.reduce((most, line) => Math.max(most, line.length), 0);
    return div()
      .id("viewer-lines")
      .flex_1()
      .min_h(0)
      .min_w(0)
      .relative()
      .font_family(codeFont())
      .text_size(codeSize())
      .child(
        div()
          .id("viewer-x")
          .size_full()
          .overflow_x_scrollbar()
          .child(
            div()
              .w_full()
              .min_w(Math.max(300, (widest * CHAR_WIDTH + LINE_COLUMNS) * codeSize()))
              .h_full()
              .child(list),
          ),
      )
      .child(Scrollbar.vertical(listId).viewport_from_layout().absolute().inset_0());
  },

  // Only a change that replaced something has anything to open.
  toggleChange(row, cx) {
    if (!row?.hunk?.old.length) return;
    const key = hunkKey(row.hunk);
    if (!this.openHunks.delete(key)) this.openHunks.add(key);
    cx.notify();
  },

  // Split once per version of the file: rows are drawn on every scroll.
  fileLines() {
    if (this.linesOf !== this.text) {
      this.linesOf = this.text;
      this.lines = fileLinesOf(this.text ?? "");
    }
    return this.lines;
  },

  // Coloured once per version too, top to bottom, so a comment or string opened on one
  // line is still one on the next. A huge file, or one the lexer fails on, gets no runs
  // here: its rows are coloured one at a time as they're drawn (`rowRuns`). The runs are
  // kept only once they're complete, so a row never shows another file's text.
  lineRuns(lines) {
    // Keyed on the path too: two files with the same text share `lines`, not a language.
    if (this.runsFor !== lines || this.runsPath !== this.file.path) {
      let runs = null;
      if (lines.length <= WHOLE_FILE_LINES) {
        try {
          runs = highlightLines(lines, lexerLanguage(this.file.path));
        } catch {}
      }
      this.runs = runs;
      this.runsFor = lines;
      this.runsPath = this.file.path;
    }
    return this.runs;
  },

  // One row's runs: from the whole-file pass when there is one, else that line on its own.
  rowRuns(row, lineRuns) {
    const runs = lineRuns?.[row.number - 1];
    if (runs) return runs;
    try {
      return tokenizeLine(row.text, lexerLanguage(this.file.path)).runs;
    } catch {
      return [{ text: row.text, kind: null }];
    }
  },

  fileRow(row, lineRuns) {
    const t = theme();
    if (row.type === "removed")
      return h_flex()
        .id(`viewer-${row.key}`)
        .h(REMOVED_ROW)
        .w_full()
        .items_center()
        .cursor_pointer()
        .child(div().h(2).w_full().bg(t.ansi1));
    const old = row.type === "old";
    const open = row.hunk && this.openHunks.has(hunkKey(row.hunk));
    // A line whose old version is showing reads as what replaced it.
    const color = old
      ? t.ansi1
      : row.hunk
        ? { added: t.ansi2, changed: open ? t.ansi2 : t.ansi3 }[row.hunk.kind]
        : null;
    const SYNTAX = syntaxColors(t);
    const runs = old ? [{ text: row.text, kind: "old" }] : this.rowRuns(row, lineRuns);
    return h_flex()
      .id(`viewer-${row.key}`)
      .h(rowHeight())
      .w_full()
      .items_center()
      .when(Boolean(color), (el) => el.bg(`${color?.slice(0, 7)}26`))
      .when(Boolean(row.hunk?.old.length), (el) => el.cursor_pointer())
      .child(
        div()
          .id(color && !old ? `viewer-mark-${row.number - 1}` : `viewer-bar-${row.key}`)
          .w(3)
          .h_full()
          .flex_none()
          .when(Boolean(color), (el) => el.bg(color)),
      )
      .child(
        div()
          .w(codeSize() * 3.5)
          .pr(codeSize())
          .flex_none()
          .text_right()
          .text_color(t.dim)
          .child(String(row.number)),
      )
      .child(
        h_flex()
          .flex_1()
          .min_w(0)
          .whitespace_nowrap()
          .children(
            runs.map((run) =>
              div()
                .flex_none()
                .whitespace_nowrap()
                .text_color(run.kind === "old" ? t.ansi1 : (SYNTAX[run.kind] ?? t.foreground))
                .child(run.text || " "),
            ),
          ),
      );
  },

  // Herdr only loads images from under its own folder, so the file is shown through a copy
  // in this mod's cache. Saving over the copy updates what's on screen, which is how a
  // changed image refreshes. Each file a tab shows gets its own name, for the same reason.
  readImage(cx) {
    const file = this.file;
    if (file.on || this.reading) return;
    if (this.imageFor !== file.path) {
      this.imageFor = file.path;
      this.imageSerial = (this.imageSerial ?? 0) + 1;
      this.imageOld = this.imageCopy;
      const ext = file.path.split(".").pop().toLowerCase();
      this.imageCopy = `mods/better-files/cache/${this.viewerId}-${this.imageSerial}.${ext}`;
      this.imageShown = null;
    }
    const copy = this.imageCopy;
    const old = this.imageOld ? `${appHome()}/${this.imageOld}` : "";
    this.imageOld = null;
    this.reading = true;
    cx.spawn(async (cx) => {
      const result = await exec(
        "sh",
        ["-c", COPY_IMAGE, "copy-image", file.path, `${appHome()}/${copy}`, old],
        {},
      ).catch(() => null);
      this.reading = false;
      if (this.file?.path !== file.path) return;
      const problem = result?.code === 0 ? null : "This file is no longer available.";
      const shown = problem ? null : copy;
      if (problem !== this.problem || shown !== this.imageShown) {
        this.problem = problem;
        this.imageShown = shown;
        cx.notify();
      }
    });
  },

  // Another machine's file isn't on this one to load.
  imageView() {
    if (this.file.on) return Message("Images on another machine can't be shown here.");
    if (this.problem) return Message(this.problem);
    if (!this.imageShown) return Message("Loading…");
    return h_flex()
      .id("viewer-image")
      .flex_1()
      .min_h(0)
      .min_w(0)
      .p(16)
      .child(image(this.imageShown).flex_1().min_w(0).h_full());
  },

  // Preview or Code, chosen per tab and kept in the registry, else the setting.
  markdownView() {
    return this.viewerEntry()?.markdown ?? this.markdownDefault ?? "preview";
  },

  showsPreview() {
    return Boolean(this.file && isMarkdown(this.file.path)) && this.markdownView() === "preview";
  },

  // Split once per version of the file, like the code view's lines.
  previewBlocks() {
    const key = `${this.file.path}\0${this.text}`;
    if (this.blocksOf !== key) {
      this.blocksOf = key;
      this.blocks = markdownBlocks(this.text ?? "", parentOf(this.file.path));
    }
    return this.blocks;
  },

  // A Markdown file's pictures, copied into the cache the way the image viewer does, each
  // under its own name for as long as the tab is open. Checked whenever the file is.
  readMarkdownImages(cx) {
    const file = this.file;
    if (!file || file.on || !isMarkdown(file.path) || this.text === undefined) return;
    this.markdownCopies ??= new Map();
    this.markdownShown ??= new Map();
    this.markdownCopying ??= new Set();
    for (const { path } of this.previewBlocks().filter((block) => block.type === "image")) {
      if (this.markdownCopying.has(path)) continue;
      if (!this.markdownCopies.has(path))
        this.markdownCopies.set(path, `mods/better-files/cache/${this.viewerId}-m${this.markdownCopies.size + 1}.${path.split(".").pop().toLowerCase()}`);
      const copy = this.markdownCopies.get(path);
      this.markdownCopying.add(path);
      cx.spawn(async (cx) => {
        const result = await exec("sh", ["-c", COPY_IMAGE, "copy-image", path, `${appHome()}/${copy}`, ""], {}).catch(() => null);
        this.markdownCopying.delete(path);
        const shown = result?.code === 0;
        if (this.markdownShown.get(path) !== shown) {
          this.markdownShown.set(path, shown);
          cx.notify();
        }
      });
    }
  },

  // A web link opens in the browser, and a link to a file here opens it like a click in
  // the tree. Anchors and other schemes do nothing.
  followLink(url, cx) {
    if (/^https?:\/\//i.test(url)) return cx.open_url(url);
    const file = this.file;
    const path = resolvePath(parentOf(file.path), url);
    if (!path || path === file.path) return;
    const root = path.startsWith(`${file.root}/`) ? file.root : parentOf(path);
    this.openFile({ path, root, on: file.on ?? null }, cx);
  },

  previewImage(block) {
    const name = block.alt || baseName(block.path);
    if (this.file.on) return Message(`${name}: images on another machine can't be shown here.`);
    const shown = this.markdownShown?.get(block.path);
    if (shown === false) return Message(`${name} isn't available.`);
    if (!shown) return Message("Loading…");
    return image(this.markdownCopies.get(block.path)).max_w_full().flex_none();
  },

  previewView() {
    return v_flex()
      .id("viewer-preview")
      .flex_1()
      .min_h(0)
      .min_w(0)
      .overflow_y_scrollbar()
      .px(24)
      .py(16)
      .gap(12)
      .children(
        this.previewBlocks().map((block, i) =>
          block.type === "image"
            ? this.previewImage(block)
            : Markdown(`viewer-md-${this.viewerId}-${i}`, block.text).on_link_click((url, cx) => this.followLink(url, cx)),
        ),
      );
  },

  viewerActions() {
    const file = this.file;
    const preview = this.viewerEntry()?.preview;
    const editors = file?.on ? [] : foundEditors();
    const markdown = Boolean(file && isMarkdown(file.path));
    const previewing = this.showsPreview();
    const showView = (view) => (cx) => {
      this.setViewer(this.viewerId, { markdown: view });
      cx.notify();
    };
    // Only changes that replaced something have old lines to show.
    const openable = this.gutterOn && !previewing ? (this.hunks ?? []).filter((hunk) => hunk.old.length).map(hunkKey) : [];
    const allOpen = openable.length > 0 && openable.every((key) => this.openHunks.has(key));
    return h_flex()
      .id("viewer-actions")
      .gap(6)
      .items_center()
      .when(markdown, (el) =>
        el.child(
          h_flex()
            .id("viewer-view")
            .gap(2)
            .child(TextButton({ id: "viewer-view-preview", label: "Preview", active: previewing, onClick: showView("preview") }))
            .child(TextButton({ id: "viewer-view-code", label: "Code", active: !previewing, onClick: showView("code") })),
        ),
      )
      .when(openable.length > 0, (el) =>
        el.child(
          TextButton({
            id: "viewer-show-old",
            label: "Expand all",
            active: allOpen,
            onClick: (cx) => {
              this.openHunks = new Set(allOpen ? [] : openable);
              cx.notify();
            },
          }),
        ),
      )
      .when(Boolean(preview), (el) =>
        el.child(
          TextButton({
            id: "viewer-keep",
            label: "Keep tab",
            onClick: (cx) => {
              this.setViewer(this.viewerId, { preview: false });
              cx.notify();
            },
          }),
        ),
      )
      .when(editors.length > 0, (el) =>
        el.child(
          this.chooser({
            id: "viewer-open-in",
            accessibilityLabel: "Open in an editor",
            width: 200,
            trigger: MenuButton({ id: "viewer-open-in-trigger", label: "Open in" }),
            choices: editors.map((e) => ({ id: e.bundle, label: e.name })),
            onChoose: (bundle) => {
              this.openInEditor(editors.find((e) => e.bundle === bundle), file.path);
            },
          }),
        ),
      );
  },

  viewerView() {
    const t = theme();
    const head = this.viewerHead();
    const inHeader = this.headerShowsTitle();
    const root = v_flex()
      .id("better-files-viewer")
      .relative()
      .size_full()
      .min_w(0)
      .min_h(0)
      .overflow_hidden()
      .bg(t.background)
      .text_color(t.foreground)
      .text_size(TEXT.body);
    if (!inHeader && head)
      root.child(
        h_flex()
          .id("viewer-bar")
          .h(30)
          .flex_none()
          .px(10)
          .gap(8)
          .items_center()
          .border_b(1)
          .border_color(t.border)
          .text_size(TEXT.small)
          .child(
            FileIcon({ icons: this.fileIcons, path: this.file.path, color: t.dim, t }),
          )
          .child(div().flex_none().truncate().max_w(260).font_medium().child(head.title))
          .child(div().flex_1().min_w(0).truncate().text_color(t.dim).child(head.detail))
          .child(this.viewerActions()),
      );
    if (this.file && isImage(this.file.path)) root.child(this.imageView());
    else if (this.problem) root.child(Message(this.problem));
    else if (this.text === undefined) root.child(Message(head ? "Loading…" : "This tab has no file."));
    else if (this.showsPreview()) root.child(this.previewView());
    else if (this.gutterOn) root.child(this.linesView());
    else root.child(v_flex().flex_1().min_h(0).child(Editor.new(this.code).flex_1().min_h(0)));
    // There's no row of its own to sit in, so the actions float over the file's corner.
    // On the file's own colour, nearly opaque, so the text under it fades out without a box.
    if (inHeader)
      root.child(
        div()
          .absolute()
          .top(6)
          .right(18)
          .p(3)
          .rounded(7)
          .bg(`${t.background.slice(0, 7)}E6`)
          .child(this.viewerActions()),
      );
    return root;
  },
};
