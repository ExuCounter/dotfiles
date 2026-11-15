// The sidebar: the folder tree, and the box for a prompt to an agent.
import { div } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { openOverlay, shared, theme } from "herdr";
import { baseName, holdsChange, TOTAL_ROWS } from "../files/model.js";
import { viewerEntries } from "../actions/open.js";
import { foundEditors } from "../actions/outside.js";
import { agentName } from "../actions/agents.js";
import { TEXT, Badge, Button, Chevron, FileIcon, Icon, markColor, IconButton, Message, Panel, PanelHeader, StatusLetter, TextBox } from "./ui.js";

const INDENT = 14;
const FOLDER_LABEL = 28;

// The folder on show, short enough to leave the refresh button room.
const folderLabel = (root) => {
  const name = root ? baseName(root) : "";
  if (!name) return null;
  return name.length > FOLDER_LABEL ? `${name.slice(0, FOLDER_LABEL)}…` : name;
};

export const treeMethods = {
  // What a menu or an agent needs to know about a row, all of it plain data: it crosses to
  // the menu's own copy of this mod.
  targetOf(relative, dir) {
    const path = `${this.root}/${relative}`;
    const change = this.marks[path];
    return {
      path,
      root: this.root,
      on: this.on ?? null,
      top: this.top,
      dir,
      relative: this.top && path.startsWith(`${this.top}/`) ? path.slice(this.top.length + 1) : relative,
      changed: Boolean(change),
      staged: Boolean(change?.staged),
    };
  },

  showRowMenu(target) {
    openOverlay({
      mod: "better-files",
      kind: "popup",
      width: 260,
      height: 520,
      props: { mode: "menu", target },
    });
  },

  fileOf(relative) {
    return { path: `${this.root}/${relative}`, root: this.root, on: this.on ?? null };
  },

  clickFile(relative, event, cx) {
    const file = this.fileOf(relative);
    if (event?.click_count === 2) this.keepFile(file, cx);
    else this.openFile(file, cx);
  },

  row(relative, name, dir, depth, t) {
    const path = `${this.root}/${relative}`;
    const open = this.folders.has(relative);
    const change = this.marks[path];
    const color = dir ? (holdsChange(this.marks, path) ? t.ansi3 : null) : markColor(change?.mark, t);
    const selected = !dir && Object.values(viewerEntries()).some((v) => v.file?.path === path);
    return h_flex()
      .id(`files-row-${relative}`)
      .h(26)
      .flex_none()
      .pl(8 + depth * INDENT)
      .pr(8)
      .gap(6)
      .min_w(0)
      .items_center()
      .rounded(7)
      .text_size(TEXT.small)
      .cursor_pointer()
      .when(selected, (el) => el.bg(t.selected))
      .when(!selected, (el) => el.hover((s) => s.bg(t.hover)))
      .on_click((event, cx) => {
        if (!dir) this.clickFile(relative, event, cx);
        else if (event?.click_count !== 2) this.toggleFolder(relative, cx);
      })
      .on_mouse_down("right", (_e, cx) => {
        cx.stop_propagation();
        this.showRowMenu(this.targetOf(relative, dir));
      })
      .child(dir ? Chevron(open) : div().w(14).flex_none())
      .child(FileIcon({ icons: this.fileIcons, path, dir, open, color: t.muted, t }))
      .child(
        div()
          .flex_1()
          .min_w(0)
          .truncate()
          .when(Boolean(color), (el) => el.text_color(color))
          .child(name),
      )
      .when(Boolean(change), (el) => el.child(StatusLetter(change.mark)))
      .when(dir && holdsChange(this.marks, path), (el) =>
        el.child(div().size(6).flex_none().rounded(3).bg(t.ansi3)),
      );
  },

  treeRows(prefix, depth, out, t) {
    for (const entry of this.entries.get(prefix) ?? []) {
      if (out.length >= TOTAL_ROWS) return;
      const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
      out.push(this.row(relative, entry.name, entry.dir, depth, t));
      if (entry.dir && this.folders.has(relative)) this.treeRows(relative, depth + 1, out, t);
    }
  },

  // The whole folder on show, in an editor or Finder. This computer's apps only.
  folderMenu(t) {
    const FINDER = "finder";
    const editors = foundEditors();
    return this.chooser({
      id: "files-folder",
      accessibilityLabel: "Open this folder",
      width: 200,
      trigger: div()
        .id("files-folder-trigger")
        .size(26)
        .flex_none()
        .flex()
        .items_center()
        .justify_center()
        .rounded(6)
        .text_color(t.dim)
        .cursor_pointer()
        .accessibility_label("Open this folder")
        .tooltip("Open this folder")
        .hover((el) => el.bg(t.hover).text_color(t.foreground))
        .child(Icon("folder", 15)),
      choices: [
        ...editors.map((e) => ({ id: e.bundle, label: `Open in ${e.name}` })),
        { id: FINDER, label: "Open in Finder" },
      ],
      onChoose: (id) => {
        if (id === FINDER) this.openWithDefault(this.root);
        else this.openInEditor(editors.find((e) => e.bundle === id), this.root);
      },
    });
  },

  composerView() {
    const t = theme();
    const { target, address } = this.composer;
    const agent = this.agentAt(address);
    return v_flex()
      .id("files-composer")
      .flex_none()
      .p(10)
      .gap(8)
      .border_t(1)
      .border_color(t.border)
      .child(
        div()
          .truncate()
          .text_size(TEXT.small)
          .font_medium()
          .child(agent ? `Send to ${agentName(agent)}` : "That agent is no longer running."),
      )
      .child(div().truncate().text_size(TEXT.caption).text_color(t.dim).child(target.relative))
      .child(TextBox({ id: "files-prompt", state: this.editor, label: "What should it do?" }))
      .child(
        h_flex()
          .gap(8)
          .justify_end()
          .child(
            Button({
              id: "files-prompt-close",
              label: "Close",
              onClick: (cx) => this.closeComposer(cx),
            }),
          )
          .child(
            Button({
              id: "files-prompt-send",
              label: this.sending ? "Sending…" : "Send",
              primary: true,
              disabled: this.sending || !agent || !this.editor.value().trim(),
              onClick: (cx) => this.sendToAgent(cx),
            }),
          ),
      );
  },

  sidebarView() {
    const t = theme();
    const failure = this.error ?? this.treeError ?? shared("better-files.error");
    const root = Panel({ id: "better-files" }).child(
      PanelHeader()
        .child(
          h_flex()
            .id("files-title")
            .flex_1()
            .min_w(0)
            .gap(6)
            .items_center()
            .child(div().flex_none().font_medium().child("Files"))
            .when(Boolean(folderLabel(this.root)), (el) => el.child(Badge(folderLabel(this.root)))),
        )
        .when(Boolean(this.root && !this.on), (el) => el.child(this.folderMenu(t)))
        .child(
          IconButton({
            id: "files-refresh",
            icon: "refresh",
            label: "Refresh",
            spinning: Boolean(this.loading),
            onClick: (cx) => this.refresh(cx),
          }),
        ),
    );
    if (failure) root.child(Message(failure, true));
    if (this.notice) root.child(Message(this.notice));
    const body = v_flex().id("files-list").flex_1().min_h(0).min_w(0).overflow_y_scrollbar().p(6);
    if (!this.root) body.child(Message("Select a space to see its files."));
    else {
      const rows = [];
      this.treeRows("", 0, rows, t);
      if (!rows.length && !this.loading) body.child(Message("This folder is empty."));
      body.children(rows);
      if (rows.length >= TOTAL_ROWS) body.child(Message(`Showing the first ${TOTAL_ROWS} rows.`));
    }
    root.child(body);
    if (this.composer) root.child(this.composerView());
    return root;
  },
};

