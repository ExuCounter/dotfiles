// Better Files: a read-only file browser. One class plays three roles, each its own copy:
//   the sidebar        the tree, and the box for a prompt to an agent
//   a viewer           a file in a centre tab
//   the menu           a popup at the pointer on right-click
// shared("better-files.*") connects them. The class is built from:
//   files/reads.js        the folder tree and Git's view of it
//   files/file-icons.js   Better Icons' pictures, when it's installed
//   actions/open.js       opening tabs, and handing a file to Better Changes
//   actions/outside.js    code editors, Finder
//   actions/agents.js     sending a file to an agent
//   actions/menus.js      popup menus
//   views/tree.js, viewer.js, context-menu.js   the drawing
// files/model.js says what the data means; views/ui.js holds every look but the token
// colours: syntax.js colours the file view's code, and Better Changes has the same file.
import { View } from "gpui-kit";
import { TextareaState } from "gpui-base";
import { appHome, exec, nextCommand, props, setShared, shared, spaces } from "herdr";
import { loadSettings, duration } from "./settings.js";
import { setCodeSize } from "./views/ui.js";
import { followFileIcons } from "./files/file-icons.js";
import { readMethods } from "./files/reads.js";
import { openMethods } from "./actions/open.js";
import { outsideMethods } from "./actions/outside.js";
import { agentMethods } from "./actions/agents.js";
import { menuMethods } from "./actions/menus.js";
import { treeMethods } from "./views/tree.js";
import { viewerMethods } from "./views/viewer.js";
import { contextMenuMethods } from "./views/context-menu.js";

const DEFAULT_SETTINGS = { refresh: { tree: "10s", file: "2s" }, editors: [], gutter: true, markdown: "preview", font_size: 0 };
const SYNC_MS = 300;

class BetterFiles extends View {
  init(given, cx) {
    const p = props() ?? given ?? {};
    this.mode = p.mode ?? "sidebar";
    if (this.mode === "menu") {
      this.menuTarget = p.target;
      this.menuSpace = spaces().find((s) => s.active)?.id;
      return;
    }
    this.menuFocus = cx.focus_handle();
    // Better Tabs draws this on a file's tab.
    setShared("mod-icons", {
      ...(shared("mod-icons") ?? {}),
      "better-files": "mods/better-files/icons/file.svg",
    });
    followFileIcons(this, cx);
    if (this.mode === "viewer") return this.initViewer(p, cx);
    this.initSidebar(cx);
  }

  initViewer(p, cx) {
    this.viewerId = p.viewer;
    this.viewerSpace = p.space;
    this.viewerFile = p.file;
    this.gutterOn = true;
    this.markdownDefault = DEFAULT_SETTINGS.markdown;
    this.hunks = [];
    this.openHunks = new Set();
    this.syncViewer(cx);
    cx.timer.every(SYNC_MS, (cx) => this.syncViewer(cx));
    cx.spawn(async (cx) => {
      const { settings } = await loadSettings("better-files", DEFAULT_SETTINGS);
      setCodeSize(settings.font_size);
      this.markdownDefault = settings.markdown === "code" ? "code" : "preview";
      cx.notify();
      // Folding can't change once a view is made, so turning the gutter off starts a new one.
      if (settings.gutter === false) {
        this.gutterOn = false;
        this.hunks = [];
        this.code?.release();
        this.code = null;
        this.text = undefined;
        this.readFile(cx);
      }
      cx.timer.every(Math.max(500, duration(settings.refresh.file, 2000)), (cx) => {
        this.readFile(cx);
        this.readHunks(cx);
      });
    });
  }

  initSidebar(cx) {
    this.startedAt = Date.now();
    this.saved = new Map();
    this.entries = new Map();
    this.folders = new Set();
    this.marks = {};
    this.editor = TextareaState.new({ placeholder: "What should it do with this?", rows: 3 });
    this.editor.on("change", (_e, cx) => cx.notify());
    this.refresh(cx);
    this.findBetterChanges(cx);
    this.findNewAgents(this.on, cx);
    this.agentsOn = this.on ?? null;
    cx.timer.every(SYNC_MS, (cx) => this.follow(cx));
    cx.spawn(async (cx) => {
      const { settings, problems } = await loadSettings("better-files", DEFAULT_SETTINGS);
      for (const problem of problems) console.warn(`better-files mod.json settings: ${problem}`);
      this.findEditors(cx, Array.isArray(settings.editors) ? settings.editors : []);
      cx.timer.every(Math.max(1000, duration(settings.refresh.tree, 10000)), (cx) => this.refresh(cx));
    });
    cx.spawn(async (cx) => {
      for (;;) if ((await nextCommand()) === "refresh") this.refresh(cx);
    });
  }

  // A closing tab takes its copies of images with it.
  async close() {
    const copies = [this.imageCopy, ...(this.markdownCopies?.values() ?? [])].filter(Boolean);
    if (copies.length) await exec("rm", ["-f", "--", ...copies.map((c) => `${appHome()}/${c}`)], {}).catch(() => {});
  }

  // Keeps up with the focused pane, tabs closing, and questions left by the menu.
  follow(cx) {
    if (this.placeKey() !== this.key) {
      this.refresh(cx);
      if ((this.on ?? null) !== this.agentsOn) {
        this.agentsOn = this.on ?? null;
        this.findNewAgents(this.on, cx);
      }
    }
    this.pruneViewers();
    this.syncCompose(cx);
  }

  render() {
    if (this.mode === "menu") return this.menuView();
    if (this.mode === "viewer") return this.viewerView();
    return this.sidebarView();
  }
}

Object.assign(
  BetterFiles.prototype,
  readMethods,
  openMethods,
  outsideMethods,
  agentMethods,
  menuMethods,
  treeMethods,
  viewerMethods,
  contextMenuMethods,
);

export default BetterFiles;
