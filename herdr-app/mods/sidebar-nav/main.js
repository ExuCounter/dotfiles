// Adapted from sidebar-nav in VladTemp27/herdr-orca (https://github.com/VladTemp27/herdr-orca), Apache-2.0.
// Sidebar nav: Orca-style links above Spaces that open mods as popups.
// The popup's size and look live in each mod's mod.json `overlay`; mod.open again closes it.
import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { theme, run } from "herdr";

const LINKS = [
  ["automations", "Automations", "mods/sidebar-nav/automations.svg"],
  ["better-config", "Mod settings", "mods/sidebar-nav/settings.svg"],
];

export default class SidebarNav extends View {
  init() {
    this.width = Infinity;
  }

  render() {
    const t = theme(), collapsed = this.width < 160;
    return v_flex().id("sidebar-nav").size_full().px(8).pt(4).gap(1).bg(t.chrome).text_size(13)
      .on_size_change((size, cx) => { if (size.width !== this.width) { this.width = size.width; cx.notify(); } })
      .children(LINKS.map(([mod, label, icon]) =>
        h_flex().id(`nav-${mod}`).h(30).flex_none().px(8).gap(10).items_center().rounded(7).cursor_pointer()
          .when(collapsed, (el) => el.justify_center().px(0))
          .text_color(t.muted).hover((s) => s.bg(t.hover).text_color(t.foreground))
          .role("button").accessibility_label(label).tooltip(label)
          .on_click(() => run("mod.open", { name: mod }))
          .child(svg(icon).size(16).flex_none())
          .when(!collapsed, (el) => el.child(div().flex_1().min_w(0).truncate().child(label)))));
  }
}
