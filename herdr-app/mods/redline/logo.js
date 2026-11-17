import { div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";

// The Redline logo: RED in red, LINE in the text colour, the red line under it, and the
// tagline in diff markers. logo.ans is the same thing for a terminal.
// A fixed red, not the theme's: the brand reads the same in every theme.
export const BRAND_RED = "#E5383B";
const RED = [
  "██████╗ ███████╗██████╗ ", "██╔══██╗██╔════╝██╔══██╗", "██████╔╝█████╗  ██║  ██║",
  "██╔══██╗██╔══╝  ██║  ██║", "██║  ██║███████╗██████╔╝", "╚═╝  ╚═╝╚══════╝╚═════╝ ",
];
const LINE = [
  "██╗     ██╗███╗   ██╗███████╗", "██║     ██║████╗  ██║██╔════╝", "██║     ██║██╔██╗ ██║█████╗  ",
  "██║     ██║██║╚██╗██║██╔══╝  ", "███████╗██║██║ ╚████║███████╗", "╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝",
];

// The block logo; `size` is the font size of one character row.
export function logo(t, { size = 9, tagline = true } = {}) {
  const row = (i) => h_flex().h(size * 1.15).items_center()
    .child(div().text_color(BRAND_RED).child(RED[i]))
    .child(div().text_color(t.foreground).child(LINE[i]));
  return v_flex().flex_none().items_start().font_family("Menlo").text_size(size).whitespace_nowrap()
    .children(RED.map((_, i) => row(i)))
    .child(div().mt(size * 0.3).h(Math.max(2, size * 0.35)).w(size * 0.6 * 53).bg(BRAND_RED))
    .when(tagline, (e) => e.child(h_flex().mt(size * 0.9).gap(size * 1.6).text_size(size * 1.2).font_family("Menlo")
      .child(h_flex().gap(6).child(div().text_color(BRAND_RED).child("-")).child(div().text_color(t.dim).child("read the diff")))
      .child(h_flex().gap(6).child(div().text_color(t.ansi2).child("+")).child(div().text_color(t.dim).child("mark it up")))
      .child(h_flex().gap(6).child(div().text_color(t.ansi2).child("✓")).child(div().text_color(t.dim).child("ship it")))));
}
