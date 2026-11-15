// The hover card beside a space row: its PR or MR with its pipeline, and its live ports,
// drawn like Herdr's menus. Opened by spaces.js as a window overlay with props
// { view: "card", space, prs, updated }.
import { div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { props, theme, shared, setShared, closeOverlay, exec, settings, notify } from "herdr";
import { prAppearance, pipelineAppearance } from "../git/pr-status.js";
import { TEXT, SIZE, RADIUS, Icon } from "./ui.js";

export const HOVER_KEY = "better-sidebar.hover";

const ago = (ms) => {
  const s = Math.max(0, Math.round((Date.now() - ms) / 1000));
  return s < 45 ? "just now" : s < 3600 ? `${Math.round(s / 60)}m ago` : s < 86400 ? `${Math.round(s / 3600)}h ago` : `${Math.round(s / 86400)}d ago`;
};
const stop = (_e, cx) => cx.stop_propagation();
const isGitLab = (pr) => String(pr.id ?? "").startsWith("gitlab:");

export class Card {
  init() {}

  // Leaving the card closes it unless the pointer went back to its row.
  hover(hovered, cx) {
    const p = props();
    setShared(HOVER_KEY, { ...(shared(HOVER_KEY) ?? {}), card: hovered });
    if (!hovered) cx.timer.after(250, () => {
      const h = shared(HOVER_KEY) ?? {};
      if (!h.card && h.row !== p.space) closeOverlay(p.overlay);
    });
  }

  copy(text) {
    exec("sh", ["-c", 'printf %s "$1" | pbcopy', "copy", text]).catch(() => null);
    notify({ title: "Link copied", body: text, timeout: 2000 });
  }

  button(id, icon, label, t, onClick) {
    return div().id(id).size(SIZE.iconSmall).flex_none().flex().items_center().justify_center().rounded(RADIUS.control)
      .text_color(t.dim).cursor_pointer().tooltip(label)
      .hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_mouse_down("left", stop).on_click((_e, cx) => { cx.stop_propagation(); onClick(cx); })
      .child(Icon(icon, 13));
  }

  label(t, text) {
    return div().px(8).pt(6).pb(3).text_size(TEXT.caption).font_medium().text_color(t.dim).child(text);
  }

  divider(t) {
    return div().h(1).mx(3).my(4).flex_none().bg(t.border);
  }

  // A PR or MR: the row opens it; its pipeline beneath opens the pipeline; copy and open on the right.
  item(t, pr) {
    const look = prAppearance(pr, t), checks = pipelineAppearance(pr, t);
    const host = isGitLab(pr) ? "GitLab" : "GitHub";
    const url = pr.url || `https://github.com/${pr.repository}/pull/${pr.number}`;
    const id = `card-pr-${pr.number}`;
    return h_flex().id(id).px(8).py(6).gap(9).items_start().rounded(RADIUS.row).cursor_pointer()
      .hover((s) => s.bg(t.hover)).on_mouse_down("left", stop)
      .on_click((_e, cx) => { cx.stop_propagation(); cx.open_url(url); })
      .child(div().pt(1).child(Icon(look.icon, 14).text_color(look.color)))
      .child(v_flex().flex_1().min_w(0).gap(2)
        .child(div().truncate().text_size(TEXT.menu).text_color(t.foreground).child(pr.title))
        .child(h_flex().gap(5).items_center().text_size(TEXT.caption).text_color(t.dim)
          .child(div().flex_none().child(`${isGitLab(pr) ? "!" : "#"}${pr.number}`))
          .child(div().flex_none().text_color(look.color).child(look.label))
          .child(div().min_w(0).truncate().child(pr.repository)))
        .when(Boolean(checks), (el) => el.child(this.pipeline(t, pr, checks))))
      .child(h_flex().flex_none().gap(1)
        .child(this.button(`${id}-copy`, "copy", "Copy link", t, () => this.copy(url)))
        .child(this.button(`${id}-open`, "external", `Open on ${host}`, t, (cx) => cx.open_url(url))));
  }

  pipeline(t, pr, checks) {
    const icon = Icon(checks.icon, 12).text_color(checks.color);
    return h_flex().id(`card-pipeline-${pr.number}`).gap(5).items_center().text_size(TEXT.caption).text_color(checks.color)
      .when(Boolean(pr.pipelineUrl), (el) => el.cursor_pointer().tooltip("Open pipeline")
        .hover((s) => s.text_color(t.foreground))
        .on_click((_e, cx) => { cx.stop_propagation(); cx.open_url(pr.pipelineUrl); }))
      .child(checks.spin ? icon.spin(900) : icon)
      .child(checks.label);
  }

  port(t, port, mono) {
    // live-ports marks a port on another machine's localhost reachable: false; this computer can't open it.
    const url = port.reachable === false ? null : `http://${port.address}`;
    const where = port.machine ?? "local";
    return h_flex().id(`card-port-${where}-${port.pid}-${port.port}`).h(SIZE.row).flex_none().px(8).gap(9).items_center()
      .rounded(RADIUS.row).tooltip(url ? `Open ${url} · PID ${port.pid}` : `PID ${port.pid} on ${port.machine}`)
      .when(Boolean(url), (el) => el.cursor_pointer().hover((s) => s.bg(t.hover))
        .on_mouse_down("left", stop).on_click((_e, cx) => { cx.stop_propagation(); cx.open_url(url); }))
      .child(div().size(6).flex_none().rounded(3).bg(t.working))
      .child(div().w(44).flex_none().font_family(mono).text_size(TEXT.small).font_medium().text_color(t.foreground).child(String(port.port)))
      .child(div().flex_none().text_size(TEXT.small).text_color(t.muted).child(port.name))
      .child(div().flex_1().min_w(0).truncate().text_size(TEXT.caption).text_color(t.dim).child(url || !port.machine ? port.address : `${port.address} on ${port.machine}`));
  }

  render() {
    const p = props(), t = theme();
    const prs = p.prs ?? [];
    const ports = shared("live-ports")?.bySpace?.[p.space] ?? [];
    const mono = settings().font_family ?? "JetBrains Mono";
    const sections = [];
    if (prs.length) {
      const noun = prs.every(isGitLab) ? "Merge request" : "Pull request";
      sections.push([this.label(t, prs.length > 1 ? `${noun}s · ${prs.length}` : noun), ...prs.map((pr) => this.item(t, pr))]);
    }
    if (ports.length) sections.push([this.label(t, `Live ports · ${ports.length}`), ...ports.map((port) => this.port(t, port, mono))]);
    return v_flex().id("space-card").w_full().p(5).gap(1).bg(t.popover).text_color(t.foreground)
      .on_hover((hovered, cx) => this.hover(hovered, cx))
      .children(sections.flatMap((rows, n) => (n ? [this.divider(t), ...rows] : rows)))
      .when(prs.length > 0 && Boolean(p.updated), (el) => el.child(h_flex().px(8).pt(4).pb(2)
        .text_size(TEXT.caption).text_color(t.dim).child(`Updated ${ago(p.updated)}`)));
  }
}
