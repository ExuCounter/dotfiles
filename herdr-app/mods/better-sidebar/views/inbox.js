// The review inbox tab, from git/mr-inbox.js: Mine (MRs I author or am assigned) and Reviews
// (MRs I review), as a tree of repository, MR and what's open on it. A click opens the thread,
// or the MR's review queue, in Better Changes.
import { div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { run, theme, shared, setShared } from "herdr";
import { inbox, inboxItems } from "../git/mr-inbox.js";
import { TEXT, RADIUS, SIZE, Icon, GroupHeader, Rail } from "./ui.js";

const MINUTE = 60000;

function ago(at) {
  const minutes = Math.round((Date.now() - at) / MINUTE);
  if (minutes < 1) return "now";
  if (minutes < 60) return `${minutes}m`;
  if (minutes < 60 * 24) return `${Math.round(minutes / 60)}h`;
  return `${Math.round(minutes / 60 / 24)}d`;
}

const when = (item) => item.updated ?? item.at;
// The MR's queue as polled, less what's been dismissed since (thread id -> last note's time)
// and what Better Changes has resolved since: it reads and writes the threads on its own clock.
const liveQueue = (mr) => {
  const dismissed = shared("review-queue.dismissed") ?? {};
  const read = (shared("better-changes.threads") ?? {})[`${mr.host}/${mr.repo}!${mr.iid}`];
  const resolved = new Set((read?.list ?? []).filter((thread) => thread.resolved).map((thread) => thread.id));
  return (mr.queue ?? []).filter((item) => !(dismissed[item.id] >= item.at) && !resolved.has(item.id));
};
const openCount = (mr) => (mr.queue ? liveQueue(mr).filter((item) => item.waitingOn === "me").length : (mr.open ?? 0));
const roleOf = (item) => item.role ?? "mine";

function look(item, t) {
  if (item.kind === "review") return { icon: "pull-request", color: t.ansi4 };
  if (item.kind === "pipeline") return { icon: "closed", color: t.ansi1 };
  if (item.kind === "conflict") return { icon: "x", color: t.ansi1 };
  if (item.kind === "comment") return { icon: "message", color: t.ansi4 };
  return { icon: "circle-dot", color: t.ansi5 };
}

export class Inbox {
  init() {
    this.busy = null; // item key -> the action under way
    this.error = null;
    this.role = localStorage.getItem("inbox.role") === "review" ? "review" : "mine";
  }

  pickRole(role, cx) {
    this.role = role;
    try {
      localStorage.setItem("inbox.role", role);
    } catch {
      /* The tab is a convenience. */
    }
    cx.notify();
  }

  roleTabs(all, t) {
    const tab = (role, label) => {
      const waiting = this.waitingCount(role, all, inbox());
      const picked = this.role === role;
      return h_flex()
        .id(`inbox-role-${role}`)
        .flex_1()
        .h(24)
        .gap(5)
        .justify_center()
        .items_center()
        .rounded(RADIUS.control)
        .cursor_pointer()
        .text_size(TEXT.label)
        .font_medium()
        .text_color(picked ? t.foreground : t.dim)
        .when(picked, (el) => el.bg(t.selected))
        .when(!picked, (el) => el.hover((s) => s.bg(t.hover).text_color(t.foreground)))
        .on_click((_e, cx) => this.pickRole(role, cx))
        .child(label)
        .when(waiting > 0, (el) =>
          el.child(div().px(5).rounded(8).bg(t.ansi5).text_color("#ffffff").text_size(TEXT.badge).child(String(waiting))),
        );
    };
    return h_flex().px(4).pb(4).gap(4).child(tab("mine", "Mine")).child(tab("review", "Reviews"));
  }

  watcher() {
    return globalThis.mrInbox;
  }

  // A thread opens on the branch's diff in Better Changes, a pipeline in the browser.
  open(item, cx) {
    if (item.kind === "pipeline") return cx.open_url(item.pipeline);
    this.act(item, "Opening", cx, async (cx) => {
      const space = await this.watcher().space(item, cx);
      run("space.select", { id: space.id });
      if (item.kind === "conflict") return;
      run("layout.show", { id: "panel" });
      run("layout.select", { stack: "panel-body", child: "changes" });
      setShared("better-changes.open-thread", {
        repo: item.repo,
        iid: item.iid,
        thread: item.thread,
        path: item.path,
        queue: true,
        at: Date.now(),
      });
    });
  }

  act(item, what, cx, work) {
    if (this.busy) return;
    this.busy = { key: item.key, what };
    this.error = null;
    cx.notify();
    cx.spawn(async (cx) => {
      try {
        await work(cx);
      } catch (error) {
        this.error = `!${item.iid}: ${error.message}`;
      } finally {
        this.busy = null;
        cx.notify();
      }
    });
  }

  // Mine counts the open threads waiting on me; Reviews, the inbox's pending items.
  waitingCount(role, all, state) {
    if (role === "mine")
      return Object.values(state.mrs ?? {})
        .filter((mr) => (mr.role ?? "mine") === "mine")
        .reduce((n, mr) => n + openCount(mr), 0);
    return all.filter((item) => roleOf(item) === role && item.status === "pending").length;
  }

  render() {
    const t = theme();
    const state = inbox();
    const all = inboxItems();
    const items = all.filter((item) => roleOf(item) === this.role && item.status !== "dismissed" && item.status !== "replied");
    const list = v_flex()
      .id("inbox-list")
      .flex_1()
      .min_h(0)
      .px(8)
      .pb(14)
      .gap(8)
      .overflow_y_scrollbar()
      .child(this.roleTabs(all, t))
      .child(this.summary(state, this.waitingCount(this.role, all, state), t));
    if (this.error) list.child(div().px(4).text_size(TEXT.small).text_color(t.ansi1).child(this.error));
    if (state.error) list.child(div().px(4).text_size(TEXT.small).text_color(t.ansi1).child(state.error));
    return list.children(this.repos(state, items, t));
  }

  summary(state, waiting, t) {
    const checked = state.at ? ago(state.at) : "…";
    const clear = waiting === 0;
    return h_flex()
      .px(4)
      .gap(5)
      .items_center()
      .text_size(TEXT.caption)
      .text_color(clear ? t.dim : t.ansi5)
      .child(Icon(clear ? "circle-check" : "circle-dot", 11))
      .child(div().flex_1().min_w(0).truncate().child(clear ? "Nothing waiting on you" : `${waiting} waiting on you`))
      .child(div().flex_none().text_color(t.dim).child(`checked ${checked}`));
  }

  // Repository, then one row per MR, then what's open on it.
  repos(state, items, t) {
    const mrs = new Map();
    for (const mr of Object.values(state.mrs ?? {}))
      if (mr.iid && (mr.role ?? "mine") === this.role) mrs.set(`${mr.repo}!${mr.iid}`, { mr, items: [] });
    for (const item of items) {
      const key = `${item.repo}!${item.iid}`;
      if (!mrs.has(key)) mrs.set(key, { mr: item, items: [] });
      mrs.get(key).items.push(item);
    }
    const byRepo = new Map();
    for (const entry of mrs.values()) {
      if (!byRepo.has(entry.mr.repo)) byRepo.set(entry.mr.repo, []);
      byRepo.get(entry.mr.repo).push(entry);
    }
    const children = (entry) => this.children(entry, t);
    const latest = (entry) => Math.max(entry.mr.updated ?? 0, ...entry.items.map(when));
    return [...byRepo.entries()]
      .sort(([, a], [, b]) => b.reduce((n, e) => n + children(e).length, 0) - a.reduce((n, e) => n + children(e).length, 0))
      .map(([repo, entries]) => {
        const folded = this.folds?.[repo] ?? false;
        const group = v_flex().child(
          GroupHeader({
            id: `inbox-repo-${repo}`,
            label: repo.split("/").pop(),
            count: entries.length,
            folded,
            onClick: (cx) => this.toggleFold(repo, cx),
          }),
        );
        if (folded) return group;
        return group.children(
          entries.sort((a, b) => children(b).length - children(a).length || latest(b) - latest(a)).map((entry) => this.mrRow(entry, t)),
        );
      });
  }

  // What's open under an MR: on mine, the review queue; on a review, the inbox's items.
  children({ mr, items }, t) {
    if (this.role === "mine") {
      const activity = shared("review-queue.activity") ?? {};
      // Sent to the agent, then its result; else whose turn it is.
      const look = (item) => {
        const { sent, result } = activity[item.id] ?? {};
        if (result && result.kind !== "not-fixed") return { icon: "check", color: t.ansi2, tip: `Agent: fixed in ${result.commit}` };
        if (result) return { icon: "circle-dot", color: t.ansi3, tip: `Agent didn't fix it: ${result.reason}` };
        if (sent) return { icon: "send", color: t.accent, tip: "With the agent" };
        return item.waitingOn === "me" ? { icon: "circle-dot", color: t.ansi5 } : { icon: "clock", color: t.dim };
      };
      return liveQueue(mr).map((item) => ({
        key: `${mr.repo}!${mr.iid}#${item.id}`,
        icon: look(item).icon,
        color: look(item).color,
        label: item.path ? `${item.path.split("/").pop()}${item.line ? `:${item.line}` : ""}` : "On the merge request",
        tip: [item.path ?? mr.title, look(item).tip].filter(Boolean).join("\n"),
        detail: item.waitingOn === "me" ? item.author : "waiting on them",
        dim: item.waitingOn !== "me",
        at: item.at,
        open: { ...mr, kind: "thread", key: `${mr.repo}!${mr.iid}#${item.id}`, thread: item.id, path: item.path },
      }));
    }
    return items
      .filter((item) => item.status === "pending")
      .sort((a, b) => (a.kind === "review" ? -1 : b.kind === "review" ? 1 : when(b) - when(a)))
      .map((item) => {
        const { icon, color } = look(item, t);
        const latest = item.notes?.[item.notes.length - 1];
        return {
          key: item.key,
          icon,
          color,
          label: item.kind === "review" ? "Review · not approved at head" : item.path ? `${item.path.split("/").pop()}${item.line ? `:${item.line}` : ""}` : "On the merge request",
          tip: item.path ?? item.summary,
          detail: item.kind === "review" ? item.author : (latest?.name ?? latest?.author ?? ""),
          dim: false,
          at: when(item),
          open: item,
        };
      });
  }

  toggleFold(key, cx) {
    this.folds ??= {};
    this.folds[key] = !this.folds[key];
    cx.notify();
  }

  // One MR on one line: title, then its pipeline, approval, threads and conflicts as icons.
  mrRow(entry, t) {
    const { mr } = entry;
    const key = `${mr.repo}!${mr.iid}`;
    const kids = this.children(entry, t);
    const open = kids.length > 0 && !(this.folds?.[key] ?? false);
    const pipeline = {
      success: [t.ansi2, "check", "Pipeline passed"],
      failed: [t.ansi1, "closed", "Pipeline failed"],
      running: [t.ansi3, "spinner", "Pipeline running"],
      pending: [t.ansi3, "clock", "Pipeline pending"],
    }[mr.pipeline] ?? (mr.pipeline ? [t.dim, "clock", `Pipeline ${mr.pipeline}`] : null);
    const approved = mr.required ? mr.approved >= mr.required : mr.approved > 0;
    const mark = (icon, color, tip) => div().id(`inbox-${key}-${icon}`).flex_none().text_color(color).tooltip(tip).child(Icon(icon, 13));
    const row = h_flex()
      .id(`inbox-mr-${key}`)
      .h(SIZE.row)
      .pl(11)
      .pr(8)
      .gap(6)
      .items_center()
      .rounded(RADIUS.control)
      .cursor_pointer()
      .hover((s) => s.bg(t.hover))
      .tooltip(`${mr.title}\n${mr.branch ?? ""} · click: review queue · ⌘-click: GitLab`)
      .on_click((e, cx) => (e.modifiers?.platform ? cx.open_url(mr.url) : this.open({ ...mr, kind: "mr", key }, cx)))
      .child(
        div()
          .id(`inbox-fold-${key}`)
          .w(12)
          .flex_none()
          .text_color(t.dim)
          .when(kids.length > 0, (el) =>
            el
              .on_click((_e, cx) => {
                cx.stop_propagation();
                this.toggleFold(key, cx);
              })
              .child(Icon(open ? "chevron-down" : "chevron-right", 11)),
          ),
      )
      .child(div().flex_none().text_size(TEXT.label).font_medium().text_color(t.accent).child(`!${mr.iid}`))
      .child(div().flex_1().min_w(0).truncate().text_size(TEXT.menu).text_color(t.foreground).child(mr.title))
      .when(Boolean(pipeline), (el) => el.child(mark(pipeline[1], pipeline[0], pipeline[2])))
      .when(approved, (el) => el.child(mark("check", t.ansi2, mr.required ? `${mr.approved}/${mr.required} approved` : "Approved")))
      .when(Boolean(mr.conflicts), (el) => el.child(mark("x", t.ansi1, "Conflicts")))
      .when(Boolean(mr.draft), (el) => el.child(mark("draft", t.dim, "Draft")))
      .when(openCount(mr) > 0, (el) =>
        el.child(
          h_flex()
            .flex_none()
            .gap(2)
            .items_center()
            .text_size(TEXT.label)
            .text_color(t.ansi5)
            .child(Icon("circle-dot", 12))
            .child(String(openCount(mr))),
        ),
      );
    if (!open) return row;
    return v_flex()
      .child(row)
      .children(kids.map((kid, i) => this.childRow(kid, i === kids.length - 1, t)));
  }

  childRow(kid, lastOne, t) {
    return h_flex()
      .id(`inbox-${kid.key}`)
      .h(26)
      .pr(8)
      .gap(6)
      .items_center()
      .rounded(RADIUS.control)
      .cursor_pointer()
      .when(kid.dim, (el) => el.opacity(0.6))
      .hover((s) => s.bg(t.hover))
      .tooltip(kid.tip)
      .on_click((_e, cx) => this.open(kid.open, cx))
      .child(Rail(lastOne ? "└" : "├", 13))
      .child(Icon(kid.icon, 12).text_color(kid.color))
      .child(div().flex_none().max_w(170).truncate().text_size(TEXT.small).text_color(t.foreground).child(kid.label))
      .child(div().flex_1().min_w(0).truncate().text_size(TEXT.caption).text_color(t.dim).child(kid.detail))
      .when(Boolean(kid.at), (el) => el.child(div().flex_none().text_size(TEXT.caption).text_color(t.dim).child(ago(kid.at))));
  }
}
