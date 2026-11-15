// Adapted from t3-actions in JinJieBeWater/herdr-t3 (https://github.com/JinJieBeWater/herdr-t3), Apache-2.0; modified here.
// Actions, as T3 Code's run button: commands you start with one click, kept in shared state.
// In a bar it draws "▶ Dev | ▾", sized to fit its block; the menu and the editor are this mod opened as overlays.
import { View, div, svg } from "gpui-kit";
import { h_flex, v_flex, InputState, Input } from "gpui-base";
import { theme, run, openOverlay, closeOverlay, props, shared, setShared, home, focused, panes, spaces, settings, nextCommand } from "herdr";
import { tip } from "./tip.js";

const MOD = "t3-actions";
// Where everyone's saved actions live: another key would lose them, whatever the mod is called.
const KEY = "t3-actions";
const ICONS = ["play", "test", "lint", "configure", "build", "debug"];
const PLACES = [["tab", "Tab"], ["right", "Right"], ["down", "Down"]];
const icon = (name) => svg(`mods/${MOD}/action-${ICONS.includes(name) ? name : "play"}.svg`);

// A button's icon and text brighten together: a hover style reaches the text but not the svg, so it's state, as in the inbox.
const glow = (view, id) => (on, cx) => {
  if (on) view.hot = id;
  else if (view.hot === id) view.hot = null;
  cx.notify();
};
const lit = (view, id, color = theme().dim) => (view.hot === id ? theme().foreground : color);

// { list: [{ id, name, command, icon, place, cwd }], last: id }
const state = () => shared(KEY) ?? { list: [] };
const primary = ({ list, last }) => list.find(a => a.id === last) ?? list[0];
const editor = (id) => openOverlay({ mod: MOD, kind: "dialog", width: 440, height: 410, props: { actions: "edit", id } });

// A menu hangs from the bar (40px, as Herdr T3's tab bar) under the click, not on the pointer, where it would cover the bar; the app keeps it in the window.
// With no press to read (assistive tech clicks without one), the app's default: the pointer.
const underBar = (press) => press && { x: press.x - 8, y: 40 * settings().zoom };

function runAction(a) {
  setShared(KEY, { ...state(), last: a.id });
  // A mod pane (a review beside its agent) has no folder: use a terminal's in the same tab, else the space's.
  const f = focused();
  const folder = a.cwd?.startsWith("~") ? home() + a.cwd.slice(1)
    : a.cwd || f?.cwd || panes().find(p => p.tab === f?.tab && p.cwd)?.cwd || spaces().find(s => s.active)?.folder;
  // shortcut: sh -c skips your shell's aliases and functions and needs sh (not on plain Windows); run them through `zsh -ic` in the command if needed.
  run("terminal.open", { argv: ["sh", "-c", a.command], name: a.name, place: a.place ?? "tab", ...(folder ? { folder } : {}) });
}

// The answer from Delete's confirm dialog.
function deleteAction(id) {
  const s = state();
  setShared(KEY, { ...s, list: s.list.filter(x => x.id !== id) });
}

// The bar's control: "▶ Dev | ▾", or "Add action" before there is one. Outlined, not filled: a fill would read as an active tab.
function control(view, t, stop) {
  // A narrow bar's layout sets it (Herdr T3's bar-measure): the icon alone, the name left to the hover label. Unset, the full control.
  const s = state(), main = primary(s), compact = shared("bar.compact");
  const box = (id) => h_flex().id(id).h(24).flex_none().items_center().rounded(6).border(1).border_color(t.border).text_size(12).on_mouse_down("left", stop);
  if (!main) return tip(view.hot, t, "action-add", "Add action", box("action-add").px(8).gap(8).text_color(lit(view, "action-add")).hover(st => st.bg(t.hover)).on_hover(glow(view, "action-add"))
    // The dialog covers it, before the pointer can report leaving it.
    .role("button").accessibility_label("Add action").on_click((_e, cx) => { view.hot = null; editor(null); cx.notify(); })
    .child(icon("play").size(14)).when(!compact, el => el.child("Add action")), { below: true });
  return box("actions").text_color(t.dim)
    // 22, the outline's inside: a hover card's wrapper has no height for h_full to fill.
    .child(tip(view.hot, t, "action-run", `Run ${main.name}`, h_flex().id("action-run").h(22).px(8).gap(8).items_center().rounded_l(6).text_color(lit(view, "action-run")).hover(st => st.bg(t.hover)).on_hover(glow(view, "action-run"))
      .role("button").accessibility_label(`Run ${main.name}`).on_click(() => runAction(main))
      .child(icon(main.icon).size(14)).when(!compact, el => el.child(div().max_w(140).truncate().child(main.name))), { below: true }))
    .child(div().w(1).h(14).flex_none().bg(t.border))
    .child(tip(view.hot, t, "action-more", "Actions", div().id("action-more").h(22).px(5).flex().items_center().rounded_r(6).text_color(lit(view, "action-more")).hover(st => st.bg(t.hover)).on_hover(glow(view, "action-more"))
      .role("button").accessibility_label("Actions").on_click((_e, cx) => {
        view.hot = null; // The menu covers it, before the pointer can report leaving it.
        openOverlay({ mod: MOD, kind: "popup", at: underBar(view.actionPress), width: 280, height: Math.min(420, 61 + s.list.length * 32), props: { actions: "menu" } });
        cx.notify();
      })
      .on_mouse_down("left", (e, cx) => { view.actionPress = e.position; stop(e, cx); })
      .child(svg("mods/workspace-chrome/chevron-down.svg").size(14)), { below: true }));
}

// The menu takes the keyboard, as the shipped menu does.
function initMenu(view, cx) {
  view.at = 0;
  view.keys = cx.focus_handle();
  view.keys.focus();
}

function menu(view) {
  const t = theme(), { list } = state(), done = () => closeOverlay(props().overlay);
  const picks = [...list.map(a => () => runAction(a)), () => editor(null)];
  const row = (id, at, i, label) => h_flex().id(id).h(32).px(8).gap(8).rounded(6).items_center().flex_none()
    .text_color(t.foreground).when(view.at === at, el => el.bg(t.selected))
    .role("button").accessibility_label(label)
    .on_hover((on, cx) => { if (on && view.at !== at) { view.at = at; cx.notify(); } })
    .on_click(() => { done(); picks[at](); })
    .child(i).child(div().flex_1().min_w(0).truncate().child(label));
  return v_flex().id("actions-menu").size_full().min_h(0).p(6).bg(t.popover).text_size(13)
    .track_focus(view.keys).on_key_down((e, cx) => {
      if (e.key === "down") view.at = (view.at + 1) % picks.length;
      else if (e.key === "up") view.at = (view.at + picks.length - 1) % picks.length;
      else if (e.key === "enter") { done(); picks[view.at](); }
      else if (e.key === "escape") done();
      else return;
      cx.stop_propagation();
      cx.notify();
    })
    .child(v_flex().id("actions-list").flex_1().min_h(0).overflow_y_scroll().children(list.map((a, at) =>
      row(`action-${a.id}`, at, icon(a.icon).size(14).text_color(t.muted), a.name)
        .child(tip(view.hot, t, `edit-${a.id}`, `Edit ${a.name}`, div().id(`edit-${a.id}`).size(20).flex_none().flex().items_center().justify_center().rounded(4).text_color(lit(view, `edit-${a.id}`))
          .hover(s => s.bg(t.raised)).on_hover(glow(view, `edit-${a.id}`)).role("button").accessibility_label(`Edit ${a.name}`)
          .on_click((_e, cx) => { cx.stop_propagation(); done(); editor(a.id); })
          .child(svg("mods/workspace-chrome/settings.svg").size(14)), { below: true })))))
    .child(div().h(1).mx(6).my(4).flex_none().bg(t.border))
    .child(row("action-new", list.length, svg("mods/workspace-chrome/plus.svg").size(14).text_color(t.muted), "Add action"));
}

// The editor dialog: this copy's own inputs, made once in init.
function initEditor(view) {
  const a = state().list.find(x => x.id === props().id);
  view.action = a;
  view.icon = a?.icon ?? "play";
  view.place = a?.place ?? "tab";
  view.inputs = [["name", "Dev"], ["command", "bun run dev"], ["cwd", "Focused terminal's folder"]].map(([k, placeholder]) => {
    const input = InputState.new({ placeholder, value: a?.[k] ?? "" });
    input.on("change", (_e, cx) => cx.notify());
    input.on("submit", () => saveEditor(view));
    return [k, input];
  });
  view.inputs[0][1].focus();
}

function saveEditor(view) {
  const v = Object.fromEntries(view.inputs.map(([k, input]) => [k, input.value().trim()]));
  if (!v.name || !v.command) return;
  const s = state(), id = view.action?.id ?? Date.now().toString(36);
  const next = { id, name: v.name, command: v.command, icon: view.icon, place: view.place, ...(v.cwd ? { cwd: v.cwd } : {}) };
  setShared(KEY, { ...s, list: view.action ? s.list.map(x => x.id === id ? next : x) : [...s.list, next] });
  closeOverlay(props().overlay);
}

function editorView(view) {
  const t = theme(), done = () => closeOverlay(props().overlay);
  const [name, command] = view.inputs.map(([, input]) => input.value().trim());
  const ok = Boolean(name && command);
  const label = (text) => div().text_size(12).text_color(t.muted).child(text);
  const field = ([k, input]) => v_flex().gap(6).child(label({ name: "Name", command: "Command", cwd: "Folder (optional)" }[k]))
    .child(h_flex().h(32).px(10).rounded(6).border(1).border_color(t.border).bg(t.input).items_center()
      .child(Input.new(input).flex_1().h_full().text_size(13).text_color(t.foreground)));
  const choice = (id, on, pick, name, child) => h_flex().id(id).h(28).px(8).gap(6).rounded(6).items_center().justify_center()
    .bg(on ? t.selected : t.input).text_color(lit(view, id, on ? t.foreground : t.dim)).on_hover(glow(view, id))
    .role("button").accessibility_label(name)
    .on_click((_e, cx) => { pick(); cx.notify(); }).child(child);
  // Buttons, title and padding as the shipped confirm dialog's, which Delete opens.
  const button = (id, text, primary, act) => {
    const on = primary && ok;
    return h_flex().id(id).h(32).px(14).items_center().rounded(8).border_1().border_color(on ? t.solid : t.input).text_size(12)
      .bg(on ? t.solid : t.raised).text_color(on ? t.solid_foreground : primary ? t.dim : t.foreground)
      .cursor_pointer().hover(s => s.opacity(0.88)).role("button").accessibility_label(text).on_click(act).child(text);
  };
  return v_flex().id("action-editor").size_full().p(18).gap(14).bg(t.popover).text_size(13)
    .child(h_flex().items_center()
      .child(div().flex_1().text_size(15).font_semibold().text_color(t.foreground).child(view.action ? "Edit action" : "Add action"))
      .child(div().text_size(11).text_color(t.dim).child("Esc")))
    .children(view.inputs.map(field))
    .child(h_flex().gap(16)
      .child(v_flex().gap(6).child(label("Icon")).child(h_flex().gap(4).children(ICONS.map(i =>
        choice(`icon-${i}`, view.icon === i, () => { view.icon = i; }, `Icon: ${i}`, icon(i).size(14)).w(28).px(0)))))
      .child(v_flex().gap(6).child(label("Run in")).child(h_flex().gap(4).children(PLACES.map(([p, text]) =>
        choice(`place-${p}`, view.place === p, () => { view.place = p; }, `Run in: ${text}`, text).text_size(12))))))
    .child(h_flex().mt_auto().gap(8).items_center()
      .when(Boolean(view.action), el => el.child(h_flex().id("action-delete").h(32).px(8).items_center().rounded(8).text_size(12).text_color(t.blocked)
        .cursor_pointer().hover(s => s.bg(t.hover)).role("button").accessibility_label("Delete action").on_click(() => {
          done();
          openOverlay({ mod: "confirm", kind: "dialog", width: 400, height: 170, props: {
            title: `Delete ${view.action.name}?`,
            detail: "This removes the action and can't be undone.",
            command: { name: `${MOD}.delete-action:${view.action.id}` },
          } });
        }).child("Delete")))
      .child(div().flex_1())
      .child(button("action-cancel", "Cancel", false, done))
      .child(button("action-save", "Save", true, () => saveEditor(view))));
}

export default class Actions extends View {
  init(_props, cx) {
    const overlay = props()?.actions;
    if (overlay === "edit") initEditor(this);
    if (overlay === "menu") initMenu(this, cx);
    // The bar's copy answers Delete's dialog: `t3-actions.delete-action:<id>`.
    if (!overlay) cx.spawn(async () => {
      for (;;) {
        const command = await nextCommand();
        if (command.startsWith("delete-action:")) deleteAction(command.slice("delete-action:".length));
      }
    });
  }

  render() {
    const overlay = props()?.actions;
    if (overlay === "menu") return menu(this);
    if (overlay === "edit") return editorView(this);
    const stop = (_e, cx) => cx.stop_propagation();
    // Local fit: draw the bar's chrome and bottom rule like its neighbours in orca-2.
    return h_flex().size_full().items_center().justify_end().bg(theme().chrome).border_b(1).border_color(theme().border)
      .child(h_flex().id("actions-fit").flex_none().pr(8).items_center().on_size_change((size) => this.fit(size)).child(control(this, theme(), stop)));
  }

  // With the block's id in props.block, it sizes that block to the control: layout.resize, which Herdr keeps with the
  // layout's clicks. on_size_change reports zoomed pixels; a layout's are logical.
  fit(size) {
    const id = props()?.block, px = Math.ceil(size.width / (Number(settings()?.zoom) || 1));
    if (!id || px === this.fitted) return;
    this.fitted = px;
    run("layout.resize", { id, px });
  }
}
