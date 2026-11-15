// Adapted from t3-actions in JinJieBeWater/herdr-t3 (https://github.com/JinJieBeWater/herdr-t3), Apache-2.0; modified here.
// node mods/t3-actions/check.cjs: main.js runs on inert elements, every view reached without a window.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

function element(kind = "div", source) {
  const node = { kind, source, items: [], handlers: {}, style: {}, hoverStyle: {} };
  const proxy = new Proxy(node, { get(target, key) {
    if (key in target) return target[key];
    return (...args) => {
      if (key === "when") { if (args[0]) args[1](proxy); }
      else if (key === "child" || key === "trigger") node.items.push(args[0]);
      else if (key === "children") node.items.push(...args[0]);
      else if (key === "on_mouse_down") node.handlers[`${key}:${args[0]}`] = args[1];
      else if (key.startsWith("on_")) node.handlers[key] = args[0];
      else if (key === "id") node.key = args[0];
      else if (key === "hover") { const hovered = element(); args[0](hovered); node.hoverStyle = hovered.style; }
      else node.style[key] = args.length === 1 ? args[0] : args;
      return proxy;
    };
  } });
  return proxy;
}
const find = (node, id) => !node || typeof node !== "object" ? null : node.key === id ? node : node.items.map(c => find(c, id)).find(Boolean) ?? null;
const strings = (node) => typeof node === "string" ? [node] : node && typeof node === "object" ? node.items.flatMap(strings) : [];
function fire(node, event, ...args) {
  assert.ok(node, `missing event target: ${event}`);
  assert.equal(typeof node.handlers[event], "function", event);
  return node.handlers[event](...args);
}
const plain = (value) => JSON.parse(JSON.stringify(value));

const state = {}, calls = [], overlays = [], commands = [], jobs = [], zoom = 1.1;
const theme = new Proxy({ foreground: "#f4f4f6", dim: "#77777f", border: "#2a2a30", hover: "#202024" }, { get: (t, k) => t[k] ?? "#a9a9b4" });
// Text fields, in the order the editor makes them.
const fields = [];
const env = {
  View: class {}, div: () => element(), h_flex: () => element("h"), v_flex: () => element("v"),
  svg: (source) => element("svg", source), Input: { new: () => element("input") }, HoverCard: { new: (id) => element("hovercard").id(id) },
  InputState: { new: ({ value }) => { const f = { text: value, on() {}, value: () => f.text, focus() {} }; fields.push(f); return f; } },
  theme: () => theme, settings: () => ({ zoom }), home: () => "/home/me", keys: () => [], window: () => ({ platform: "macos" }),
  shared: (key) => state[key], setShared: (key, value) => { state[key] = value; },
  run: (name, args) => calls.push([name, plain(args)]),
  openOverlay: (spec) => overlays.push(spec), closeOverlay() {},
  focused: () => ({ tab: "b", cwd: "/repo" }), panes: () => [], spaces: () => [{ active: true, folder: "/space" }],
  nextCommand: () => commands.length ? Promise.resolve(commands.shift()) : new Promise(() => {}),
};
const source = ["tip.js", "main.js"].map(file => fs.readFileSync(path.join(__dirname, file), "utf8")).join("\n")
  .replace(/^import .*;\r?\n/gm, "").replace("export default class", "globalThis.Mod = class").replace(/^export /gm, "");
const cx = { notify() {}, stop_propagation() {}, spawn: (fn) => jobs.push(fn), focus_handle: () => ({ focus() {} }) };
const load = (props = {}) => {
  const context = vm.createContext({ ...env, props: () => props });
  vm.runInContext(source, context, { filename: "main.js" });
  const mod = new context.Mod();
  mod.init?.(props, cx);
  return mod;
};

// Every icon it names is on disk.
for (const name of JSON.parse(/const ICONS = (\[[^\]]+\])/.exec(source)[1])) assert.ok(fs.existsSync(path.join(__dirname, `action-${name}.svg`)), `icon on disk: ${name}`);

// None yet: "Add action", outlined, brightening with its icon on hover; it opens the editor.
const bar = load({ block: "actions" });
assert.ok(find(bar.render(), "action-add").style.border, "outlined, as a control on its own in any bar");
assert.equal(find(bar.render(), "action-add").style.text_color, theme.dim);
fire(find(bar.render(), "action-add"), "on_hover", true, cx);
assert.equal(find(bar.render(), "action-add").style.text_color, theme.foreground, "its icon brightens with its text");
fire(find(bar.render(), "action-add"), "on_click", {}, cx);
assert.deepEqual(plain(overlays.at(-1)), { mod: "t3-actions", kind: "dialog", width: 440, height: 410, props: { actions: "edit", id: null } });

// Some: "▶ Dev | ▾" in one outline, a rule between.
state["t3-actions"] = { list: [{ id: "a", name: "Dev", command: "bun dev" }, { id: "b", name: "Test", command: "bun test", place: "right", cwd: "~/x" }] };
const control = find(bar.render(), "actions");
assert.ok(control.style.border);
assert.deepEqual(control.items.map(n => typeof n.key === "string" ? n.key : n.kind), ["tip-action-run", "div", "tip-action-more"]);
assert.equal(find(control, "tip-action-more").style.anchor, "top_center", "the top bar has no room above: its label opens below");
assert.deepEqual(strings(find(control, "action-run")), ["Dev"]);
fire(find(control, "action-run"), "on_click");
assert.deepEqual(calls.at(-1), ["terminal.open", { argv: ["sh", "-c", "bun dev"], name: "Dev", place: "tab", folder: "/repo" }]);
// The menu hangs from the bar under the press; with none (assistive tech), at the pointer.
fire(find(bar.render(), "action-more"), "on_click", {}, cx);
assert.equal(overlays.at(-1).at, undefined);
fire(find(bar.render(), "action-more"), "on_mouse_down:left", { position: { x: 1000, y: 20 } }, cx);
fire(find(bar.render(), "action-more"), "on_click", {}, cx);
assert.deepEqual(plain(overlays.at(-1).at), { x: 992, y: 40 * zoom });
assert.equal(overlays.at(-1).mod, "t3-actions");

// The menu: a row runs its action and makes it the one ▶ runs; a gear edits it.
const menu = load({ actions: "menu" });
fire(find(menu.render(), "action-b"), "on_click");
assert.deepEqual(calls.at(-1), ["terminal.open", { argv: ["sh", "-c", "bun test"], name: "Test", place: "right", folder: "/home/me/x" }]);
assert.deepEqual(strings(find(bar.render(), "action-run")), ["Test"]);
fire(find(menu.render(), "edit-a"), "on_click", {}, cx);
assert.deepEqual(plain(overlays.at(-1).props), { actions: "edit", id: "a" });

// The editor saves an edit in place, and a new one at the end.
fields.length = 0;
const edit = load({ actions: "edit", id: "a" });
fields[1].text = "bun run dev";
fire(find(edit.render(), "action-save"), "on_click");
assert.equal(state["t3-actions"].list[0].command, "bun run dev");
fields.length = 0;
const add = load({ actions: "edit", id: null });
fire(find(add.render(), "action-save"), "on_click");
assert.equal(state["t3-actions"].list.length, 2, "no name or command, nothing saved");
fields[0].text = "Lint"; fields[1].text = "bun lint";
fire(find(add.render(), "action-save"), "on_click");
assert.deepEqual(plain(state["t3-actions"].list.map(a => a.name)), ["Dev", "Test", "Lint"]);

// It sizes its block to the control, in logical pixels, once per change; without a block it leaves the layout alone.
calls.length = 0;
const fit = find(bar.render(), "actions-fit");
assert.equal(fit.style.pr, 8, "its own gap to what follows it");
fire(fit, "on_size_change", { width: 110 });
fire(fit, "on_size_change", { width: 110 });
assert.deepEqual(calls, [["layout.resize", { id: "actions", px: 100 }]]);
fire(find(load().render(), "actions-fit"), "on_size_change", { width: 220 });
assert.equal(calls.length, 1);
// Local fit: the root paints the bar's chrome (orca-2); the control itself stays unfilled.
assert.ok([find(bar.render(), "actions"), find(bar.render(), "action-run")].every(n => !n.style.bg), "no fill at rest: the bar's own background shows");

// In a narrow bar the icon stands alone; the hover label and the accessibility label keep the name.
state["bar.compact"] = true;
assert.deepEqual(strings(find(bar.render(), "action-run")), []);
assert.equal(find(bar.render(), "action-run").style.accessibility_label, "Run Test");
assert.ok(find(bar.render(), "action-more"), "the menu stays");
const added = state["t3-actions"];
state["t3-actions"] = { list: [] };
assert.deepEqual(strings(find(bar.render(), "action-add")), []);
assert.equal(find(bar.render(), "action-add").style.accessibility_label, "Add action");
state["t3-actions"] = added;
delete state["bar.compact"];

(async () => {
  // What opens over its button drops its hover: the pointer can't report leaving.
  state["t3-actions"] = { list: [{ id: "a1", name: "Dev", command: "x" }, { id: "a2", name: "Test", command: "y" }] };
  const view = load();
  fire(find(view.render(), "action-more"), "on_hover", true, cx);
  fire(find(view.render(), "action-more"), "on_click", {}, cx);
  assert.equal(view.hot, null, "the menu's button doesn't stay lit");
  fire(find(view.render(), "action-more"), "on_hover", true, cx);
  const card = find(view.render(), "tip-action-more").style.content;
  assert.deepEqual(strings(card), ["Actions"], "its label, as T3's, while lit");

  // The menu goes by arrows and Enter.
  const selected = (n) => find(n.render(), "action-a1").style.bg === theme.selected;
  const menu = load({ actions: "menu" }), key = (k) => fire(find(menu.render(), "actions-menu"), "on_key_down", { key: k }, cx);
  assert.ok(selected(menu), "it opens on the first row");
  key("up");
  assert.equal(find(menu.render(), "action-new").style.bg, theme.selected, "up wraps to the last row");
  overlays.length = 0;
  key("enter");
  assert.equal(overlays.pop().props.actions, "edit");

  // Delete asks; only the dialog's answer, split as the app splits it, deletes. Only the bar's copy hears it.
  jobs.length = 0;
  load();
  const heard = jobs.length;
  const edit = load({ actions: "edit", id: "a1" });
  assert.equal(jobs.length, heard, "an overlay's copy doesn't listen");
  fire(find(edit.render(), "action-delete"), "on_click", {}, cx);
  const { mod, props } = overlays.pop();
  assert.deepEqual([mod, props.title], ["confirm", "Delete Dev?"]);
  assert.equal(state["t3-actions"].list.length, 2, "the click only asks");
  const dot = props.command.name.indexOf(".");
  assert.equal(props.command.name.slice(0, dot), "t3-actions");
  commands.push(props.command.name.slice(dot + 1));
  jobs[0]();
  await new Promise((resolve) => setImmediate(resolve));
  assert.deepEqual(plain(state["t3-actions"].list.map((a) => a.id)), ["a2"]);

  console.log("ok: Add action and ▶ | ▾ outlined, run, menu under the press and by keys, editor saves, Delete asks, the block sized to fit");
})().catch((e) => { console.error(e); process.exit(1); });
