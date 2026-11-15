// Adapted from t3-actions in JinJieBeWater/herdr-t3 (https://github.com/JinJieBeWater/herdr-t3), Apache-2.0; modified here.
// A hover label as T3's (its ui/tooltip.tsx): small and dark, the label with its key, and under it a dim hint if there is one.
// `.tooltip()` takes only a string, in the shell's own style, hence a HoverCard. scripts/sync.sh copies this to the mods that use it.
import { div } from "gpui-kit";
import { v_flex, HoverCard } from "gpui-base";
import { keys, window } from "herdr";

// An action's key as the new menu writes it: ⇧⌘O. Read from the bindings, so a rebound key says so.
function keyOf(action) {
  const k = keys().find(b => b.action === action);
  if (!k?.keys.trim()) return "";
  const mac = window()?.platform === "macos";
  const names = mac ? { ctrl: "⌃", alt: "⌥", shift: "⇧", cmd: "⌘", fn: "fn" } : { ctrl: "Ctrl", alt: "Alt", shift: "Shift", cmd: "Super", fn: "Fn" };
  const alias = { secondary: mac ? "cmd" : "ctrl", super: "cmd", win: "cmd" };
  return k.keys.trim().split(/\s+/).map(stroke => {
    const parts = stroke.split("-");
    let key = parts.pop();
    if (key === "") { key = "-"; parts.pop(); }
    const held = new Set(parts.map(m => alias[m.toLowerCase()] ?? m.toLowerCase()));
    if (/^[A-Z]$/.test(key)) held.add("shift");
    const label = key.length === 1 ? key.toUpperCase() : key[0].toUpperCase() + key.slice(1).toLowerCase();
    return [...Object.keys(names).filter(m => held.has(m)).map(m => names[m]), label].join(mac ? "" : "+");
  }).join(" ");
}

// Above, as T3's. `below` for what has no room up there: a HoverCard doesn't flip as T3's does, it is pushed back over its trigger and closes.
export function tip(hot, t, id, label, trigger, { action, hint, below, delay = 150 } = {}) {
  const key = action ? keyOf(action) : "";
  return HoverCard.new(`tip-${id}`).anchor(below ? "top_center" : "bottom_center").open_delay(delay).close_delay(0).trigger(trigger)
    // Only while lit: a dialog opened from the button hides the pointer's leaving, and the card would stay up over it.
    .content(hot !== id ? div() : v_flex().when(below, el => el.mt(4)).when(!below, el => el.mb(4)).px(8).py(4).rounded(6).border(1).border_color(t.border).bg(t.chrome).shadow_md().text_size(12).text_color(t.foreground)
      .child(div().child(key ? `${label} (${key})` : label))
      .when(Boolean(hint), el => el.child(div().text_color(t.muted).child(hint))));
}

// A mark with no words of its own (a status, a machine) says what it is on hover too, lit only to show its label.
export function tipMark(view, t, id, label, mark, options) {
  if (!label) return mark;
  const lit = div().id(id).flex_none().on_hover((on, cx) => {
    if (on) view.hot = id;
    else if (view.hot === id) view.hot = null;
    cx.notify();
  }).child(mark);
  return tip(view.hot, t, id, label, lit, options);
}
