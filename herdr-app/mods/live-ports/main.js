// Live ports: a status-bar button (scans each machine with spaces and publishes to shared "live-ports")
// and, with props.view "popup", the list it opens.
import { View, div, svg } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { spaces, panes, machines, theme, run, props, exec, shared, setShared, settings, window, openOverlay, closeOverlay, nextCommand } from "herdr";
import { scanPorts, portUrl, SHARED_KEY } from "./scan.js";

const SCAN_MS = 4000;
// Fixed row heights let the bar place the popup exactly above its button.
const SIZE = { width: 380, head: 40, group: 34, row: 54, empty: 44, max: 440 };
const icon = (name, size = 13) => svg(`mods/live-ports/${name}.svg`).size(size).flex_none();
const mono = () => settings().font_family ?? "JetBrains Mono";
const data = () => shared(SHARED_KEY) ?? { bySpace: {}, external: [] };
const groupsOf = (d) => spaces().filter((s) => d.bySpace[s.id]?.length).map((s) => ({ space: s, ports: d.bySpace[s.id] }));

function popupHeight(d) {
  const groups = groupsOf(d);
  const body = groups.length
    ? groups.reduce((h, g) => h + SIZE.group + g.ports.length * SIZE.row, 0)
    : SIZE.empty;
  return SIZE.head + Math.min(SIZE.max, body + (d.external.length ? SIZE.group : 0));
}

export default class LivePorts extends View {
  init(_props, cx) {
    this.popup = props()?.view === "popup" || Boolean(props()?.overlay);
    this.showExternal = false;
    if (this.popup) return;
    this.scan(cx);
    cx.timer.every(SCAN_MS, (cx) => window().active && this.scan(cx));
    // "live-ports.open" in keys.json opens the popup over the button.
    cx.spawn(async () => { for (;;) if ((await nextCommand()) === "open") this.open(); });
  }

  scan(cx) {
    if (this.busy) return;
    this.busy = true;
    cx.spawn(async (cx) => {
      try {
        const next = await scanPorts(spaces(), panes(), machines(), window()?.platform, data());
        const text = JSON.stringify(next);
        // setShared redraws every mod, so only publish real changes.
        if (text !== JSON.stringify(data())) setShared(SHARED_KEY, next);
      } catch (e) {
        console.warn(`live-ports scan failed: ${e}`);
      }
      this.busy = false;
      cx.notify();
    });
  }

  render(cx) {
    return this.popup ? this.renderPopup(cx) : this.renderButton(cx);
  }

  renderButton(cx) {
    const t = theme();
    const d = data();
    const count = Object.values(d.bySpace).reduce((n, l) => n + l.length, 0);
    this.viewport = globalThis.window?.viewport_size?.();
    return h_flex().size_full().justify_end().px(8).items_center().bg(t.chrome).border_t(1).border_color(t.border)
      .child(h_flex().id("ports-button").h(20).px(7).gap(5).items_center().rounded(5)
        .text_size(11.8).text_color(count ? t.foreground : t.muted)
        .cursor_pointer().hover((s) => s.bg(t.hover))
        .tooltip(`${count} workspace · ${d.external.length} external ports`)
        .on_mouse_move((e) => { this.anchor = e.bounds; })
        .on_mouse_down("left", (e) => { this.anchor = e.bounds ?? this.anchor; })
        .on_click(() => this.open())
        .child(icon("plug"))
        .child(String(count)));
  }

  // Bottom edge 6px above the button, right edges aligned.
  open() {
    const height = popupHeight(data());
    const zoom = settings().zoom ?? 1;
    const v = this.viewport;
    const b = this.anchor ?? (v && { x: v.width - 40, y: v.height - 24, width: 32, height: 20 });
    const at = b ? { x: Math.max(8, b.x + b.width - SIZE.width * zoom), y: Math.max(8, b.y - height * zoom - 6) } : "pointer";
    openOverlay({ mod: "live-ports", kind: "popup", at, props: { view: "popup", height }, width: SIZE.width, height });
  }

  renderPopup(cx) {
    const t = theme();
    const d = data();
    const groups = groupsOf(d);
    const count = groups.reduce((n, g) => n + g.ports.length, 0);
    return v_flex().w_full().h(props()?.height ?? popupHeight(d)).bg(t.popover).text_color(t.foreground).text_size(13)
      .child(h_flex().h(SIZE.head).flex_none().px(14).gap(8).items_center().border_b(1).border_color(t.border)
        .child(icon("plug", 14).text_color(t.muted))
        .child(div().font_medium().child("Ports"))
        .child(div().flex_1())
        .child(div().text_size(12).text_color(t.muted).child(`${count} workspace · ${d.external.length} external`)))
      .child(v_flex().id("ports-list").flex_1().min_h(0).overflow_y_scrollbar()
        .when(!groups.length, (el) => el.child(div().h(SIZE.empty).flex_none().px(14).flex().items_center().text_size(12).text_color(t.dim).child("No ports listening in your worktrees.")))
        .children(groups.flatMap((g) => [this.groupHeader(g, t), ...g.ports.map((p) => this.portRow(p, t))]))
        .when(d.external.length > 0, (el) => el
          .child(this.externalHeader(d.external.length, t))
          .when(this.showExternal, (el) => el.children(d.external.map((p) => this.portRow(p, t))))));
  }

  groupHeader({ space, ports }, t) {
    return h_flex().id(`group-${space.id}`).h(SIZE.group).flex_none().px(14).gap(8).items_center().bg(t.raised)
      .border_b(1).border_color(t.border).cursor_pointer().hover((s) => s.bg(t.hover))
      .tooltip("Go to this space")
      .on_click(() => { run("space.select", { id: space.id }); closeOverlay(props().overlay); })
      .child(div().flex_1().min_w(0).truncate().child(space.name))
      .child(icon("folder").text_color(t.muted))
      .child(div().text_size(12).text_color(t.muted).child(String(ports.length)));
  }

  externalHeader(n, t) {
    return h_flex().id("group-external").h(SIZE.group).flex_none().px(14).gap(8).items_center().bg(t.raised)
      .border_b(1).border_color(t.border).text_color(t.muted).cursor_pointer().hover((s) => s.bg(t.hover))
      .on_click((_e, cx) => { this.showExternal = !this.showExternal; cx.notify(); })
      .child(div().flex_1().child(this.showExternal ? "▾ Other processes" : "▸ Other processes"))
      .child(div().text_size(12).child(String(n)));
  }

  portRow(p, t) {
    const action = (id, name, tip, onClick) => div().id(id).size(22).flex().items_center().justify_center().rounded(5)
      .text_color(t.muted).cursor_pointer().tooltip(tip).hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_click((_e, cx) => { cx.stop_propagation(); onClick(cx); })
      .child(icon(name, 13));
    const where = p.machine ?? "local";
    const url = portUrl(p);
    return h_flex().id(`port-${where}-${p.pid}-${p.port}`).h(SIZE.row).flex_none().px(14).pt(9).gap(14).items_start()
      .border_b(1).border_color(t.border).hover((s) => s.bg(t.hover))
      .child(div().w(56).flex_none().font_family(mono()).font_bold().child(String(p.port)))
      .child(v_flex().flex_1().min_w(0).gap(2)
        .child(div().truncate().text_color(t.muted).child(p.name))
        // A port another machine's localhost holds, which this computer can't open, says where it is.
        .child(div().truncate().text_size(12).text_color(t.dim).child(url || !p.machine ? p.address : `${p.address} on ${p.machine}`)))
      .child(h_flex().gap(2).items_center()
        .when(Boolean(url), (el) => el.child(action(`open-${where}-${p.port}`, "external", "Open in browser", (cx) => cx.open_url(url))))
        .child(action(`stop-${where}-${p.pid}-${p.port}`, "stop", `Stop ${p.name} (PID ${p.pid})`, () => this.stop(p))));
  }

  // Kill (on the machine it runs on), then drop it from the shared list; the next scan confirms.
  stop(p) {
    const on = p.machine ?? null;
    exec("kill", [String(p.pid)], { on }).catch(() => null);
    const d = data();
    const drop = (l) => l.filter((x) => x.pid !== p.pid || (x.machine ?? null) !== on);
    const bySpace = Object.fromEntries(Object.entries(d.bySpace).map(([k, l]) => [k, drop(l)]).filter(([, l]) => l.length));
    setShared(SHARED_KEY, { bySpace, external: drop(d.external) });
  }
}
