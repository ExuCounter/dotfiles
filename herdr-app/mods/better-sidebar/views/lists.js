// Spaces and agents in one block. Combined (the default): tabs for Spaces, with
// each space's tabs and agents under it, and Agents. With `combined: false` in the settings: the
// two lists one above the other, as two blocks of this mod would draw them.
import { v_flex, h_flex } from "gpui-base";
import { agents, focused, theme, setAgentOrder, shared, setShared, run } from "herdr";
import { Spaces } from "./spaces.js";
import { Agents } from "./agents.js";
import { Inbox } from "./inbox.js";
import { pendingItems } from "../git/mr-inbox.js";
import { TEXT, Badge, Rail, Icon, IconButton } from "./ui.js";

const TABS = ["spaces", "agents", "inbox"];
const ROWS = "better-sidebar.rows";

// The next row of the Spaces tree, an agent or a tab with none, from the one on screen.
export function stepRow(direction) {
  const rows = shared(ROWS) ?? [];
  if (!rows.length) return;
  const now = focused();
  let at = rows.findIndex((row) => (row.pane ? row.pane === now?.pane : row.tab === now?.tab));
  if (at < 0) at = rows.findIndex((row) => row.tab === now?.tab);
  const row = rows[(at + direction + rows.length) % rows.length];
  if (row.pane) run("pane.focus", { pane: row.pane });
  else {
    run("space.select", { id: row.space });
    run("tab.select", { id: row.tab });
  }
}

export class Lists {
  init(props, cx) {
    this.spaces = new Spaces();
    this.spaces.init(props, cx);
    this.agents = new Agents();
    this.agents.init(props, cx);
    this.inbox = new Inbox();
    this.inbox.init();
    const saved = localStorage.getItem("lists.tab");
    this.tab = TABS.includes(saved) ? saved : "spaces";
  }

  pick(tab, cx) {
    this.tab = tab;
    localStorage.setItem("lists.tab", tab);
    cx.notify();
  }

  render() {
    const t = theme();
    const collapsed = this.spaces.collapsed();
    const root = v_flex()
      .id("better-sidebar-lists")
      .size_full()
      .min_h(0)
      .bg(t.chrome)
      .text_size(TEXT.body)
      .on_size_change((size, cx) => this.spaces.resized(size, cx));
    this.spaces.under = null;
    this.spaces.quiet = null;
    this.spaces.above = null;
    // The rail has no room for tabs: both lists, as numbers.
    if (!this.spaces.settings.combined || collapsed)
      return root
        .child(
          v_flex()
            .flex_1()
            .min_h(0)
            .child(this.spaces.header(t, collapsed))
            .child(this.spaces.body(t, collapsed)),
        )
        .child(v_flex().flex_1().min_h(0).child(this.agents.render()));

    const view = this.agents.readView();
    root.child(this.tabBar(t, view));
    // A save reloads the module but keeps this copy's fields: an inbox from the old build would
    // keep drawing with the old build's methods.
    if (!(this.inbox instanceof Inbox)) {
      this.inbox = new Inbox();
      this.inbox.init();
    }
    if (this.tab === "inbox") return root.child(this.inbox.render());
    if (this.tab !== "spaces") return root.child(this.agents.render({ view, heading: false }));

    // Spaces, each with its tabs and agents beneath in tab order, so rows don't move as
    // their state changes; next-agent keys follow that order.
    const nested = { ...view, sort: { id: "grouped" }, byPriority: false, nested: true };
    const order = [];
    const rows = [];
    const all = agents();
    // Pinned agents go above every space, in the Agents tab's Pinned group.
    const pinned = view.groups.find((g) => g.id === "pinned");
    const pins = pinned?.members.map((a) => a.address) ?? [];
    order.push(...pins);
    rows.push(...(pinned?.members ?? []).map((a) => ({ pane: a.pane, tab: a.tab })));
    this.spaces.above = () => (pinned ? this.agents.groupRows(pinned, 0, view, t) : []);
    const nest = (lines, row) => h_flex().children(lines.map((l) => Rail(l))).child(row.flex_1().min_w(0));
    // A space's agents hang from its line; a main space's worktrees come after them,
    // so its line carries on, and a worktree's own agents sit one step further in.
    // Every tab shows: a tab with agents as its agents, any other as itself.
    const shownTab = focused()?.tab;
    const plain = (tab) => !all.some((a) => a.tab === tab.id);
    this.spaces.under = ({ w, tree, kids }) => {
      const items = w.tabs.flatMap((tab) =>
        plain(tab)
          ? tab.settled ? [] : [{ tab }]
          : all.filter((a) => a.tab === tab.id && !pins.includes(a.address)).map((a) => ({ a })),
      );
      order.push(...items.filter((x) => x.a).map((x) => x.a.address));
      rows.push(...items.map((x) => (x.a ? { pane: x.a.pane, tab: x.a.tab } : { space: w.id, tab: x.tab.id })));
      const before = tree ? [tree.startsWith("└") ? "" : "│"] : [];
      return items.flatMap((x, i) => {
        const last = i === items.length - 1 && !kids;
        const [row, ...subs] = x.a
          ? this.agents.agentWithSubs(x.a, i, nested, t)
          : [this.agents.tabRow(w, x.tab, x.tab.id === shownTab, t)];
        return [nest([...before, last ? "└" : "├"], row), ...subs.map((s) => nest([...before, last ? "" : "│"], s))];
      });
    };
    // One row lit: a space whose focused agent or tab shows beneath it leaves it to that row.
    this.spaces.quiet = (w) =>
      all.some((a) => a.space === w.id && a.focused) || w.tabs.some((tab) => tab.id === shownTab && plain(tab));
    const body = this.spaces.body(t, false);
    setAgentOrder(order);
    const text = JSON.stringify(rows);
    if (text !== this.rowsText) {
      this.rowsText = text;
      setShared(ROWS, rows);
    }
    return root.child(body);
  }

  // Tabs side by side from the left, the picked one filled.
  tabBar(t, view) {
    const tab = (id, label, count) =>
      h_flex()
        .id(`lists-tab-${id}`)
        .px(10)
        .h(24)
        .gap(5)
        .justify_center()
        .items_center()
        .rounded(6)
        .cursor_pointer()
        .text_size(TEXT.label)
        .font_medium()
        .text_color(this.tab === id ? t.foreground : t.dim)
        .when(this.tab === id, (el) => el.bg(t.selected))
        .when(this.tab !== id, (el) => el.hover((s) => s.bg(t.hover).text_color(t.foreground)))
        .on_click((_e, cx) => this.pick(id, cx))
        .child(label)
        // The count badge the group headers use.
        .when(count !== null, (el) => el.child(Badge(count)));
    const waiting = pendingItems().length;
    const inbox = h_flex()
      .id("lists-tab-inbox")
      .px(8)
      .h(24)
      .gap(4)
      .items_center()
      .rounded(6)
      .cursor_pointer()
      .text_size(TEXT.label)
      .font_medium()
      .text_color(waiting ? t.ansi5 : this.tab === "inbox" ? t.foreground : t.dim)
      .tooltip(waiting ? `Inbox · ${waiting} waiting on you` : "Inbox")
      .when(this.tab === "inbox", (el) => el.bg(t.selected))
      .when(this.tab !== "inbox", (el) => el.hover((s) => s.bg(t.hover)))
      .on_click((_e, cx) => this.pick("inbox", cx))
      .child(Icon("inbox", 13))
      .child("Inbox")
      .when(waiting > 0, (el) => el.child(String(waiting)));
    return h_flex()
      .px(8)
      .pt(6)
      .pb(6)
      .mb(4)
      .border_b(1)
      .border_color(t.border)
      .flex_none()
      .gap(6)
      .items_center()
      .child(
        h_flex()
          .flex_1()
          .gap(2)
          .child(tab("spaces", "Spaces", null))
          .child(tab("agents", "Agents", view.count))
          .child(inbox),
      )
      .when(this.tab === "spaces", (el) => el.child(this.spaces.newSpaceButton()))
      .when(this.tab === "agents", (el) => el.child(this.agents.sortMenu()))
      .when(this.tab === "inbox", (el) =>
        el.child(
          IconButton({
            id: "inbox-refresh",
            icon: "refresh",
            label: "Check GitLab now",
            iconSize: 14,
            muted: true,
            onClick: (cx) => globalThis.mrInbox?.poll(cx),
          }),
        ),
      );
  }
}
