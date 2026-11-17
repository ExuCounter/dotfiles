import { div } from "gpui-kit";
import { v_flex, h_flex, Input } from "gpui-base";

// The panel's Overview and Pipeline tabs. Both draw from the launcher (L): its state, its
// buttons and its actions; the data comes from hosting.js (status, pipeline).

const dur = (s) => (s == null ? "" : s < 60 ? `${Math.round(s)}s` : `${Math.floor(s / 60)}m ${String(Math.round(s % 60)).padStart(2, "0")}s`);

export const JOB_LOOK = {
  success: ["✓", "ansi2"], failed: ["✗", "ansi1"], running: ["●", "working"], pending: ["○", "dim"],
  canceled: ["⊘", "dim"], skipped: ["»", "dim"], manual: ["▶", "muted"],
};

const checkbox = (t, id, label, on, onClick, disabled = false) => h_flex().id(id).gap(6).items_center().text_size(12)
  .when(!disabled, (e) => e.cursor_pointer().on_click((_e, cx) => onClick(cx)))
  .when(disabled, (e) => e.opacity(0.5))
  .child(div().size(14).flex_none().flex().items_center().justify_center().rounded(3).border_1()
    .border_color(on ? t.accent : t.dim).text_size(10).text_color(t.accent).child(on ? "✓" : ""))
  .child(div().child(label));

const section = (t, title) => div().pt(6).text_size(10.5).text_color(t.dim).child(title.toUpperCase());

// ---- Overview: can it merge, what's blocking, merge, draft, labels / assignees / reviewers ----

export function overview(L, t, row) {
  const s = L.mrStatus.get(row.number);
  if (!s || s.loading) return div().p(16).text_color(t.dim).child("Loading…");
  if (s.error) return div().p(16).text_size(12).text_color(t.ansi1).child(s.error);
  const gh = L.repo.provider === "github", mark = L.mark();
  const o = L.mergeOpts(row.number, s);
  const ciOnly = s.blockers.length > 0 && s.blockers.every((b) => /pipeline|checks/i.test(b));
  const canMerge = s.state.startsWith("open") && (s.mergeable || (o.auto && ciOnly));
  const busy = Boolean(L.busyAct);

  const state = v_flex().gap(6).p(12).rounded(8).border_1()
    .border_color(s.mergeable ? t.ansi2 : s.blockers.length ? t.blocked : t.border)
    .child(h_flex().gap(8).items_center()
      .child(div().text_size(13).font_semibold().text_color(s.mergeable ? t.ansi2 : t.blocked)
        .child(!s.state.startsWith("open") ? `This request is ${s.state}` : s.mergeable ? "Ready to merge" : "Can't merge yet"))
      .when(s.draft, (e) => e.child(div().px(6).rounded(4).bg(t.raised).text_size(11).text_color(t.muted).child("Draft")))
      .child(div().flex_1())
      .child(L.button(t, "rv-draft-toggle", s.draft ? "Mark as ready" : "Mark as draft", (cx) => L.toggleDraft(row, s, cx), { disabled: busy })))
    .children(s.blockers.map((b) => div().text_size(12).text_color(t.foreground).child(`• ${b}`)))
    .when(s.conflicts && !s.blockers.some((b) => /conflict/i.test(b)), (e) => e.child(div().text_size(12).child("• Has merge conflicts")))
    .when(typeof s.behind === "number" && s.behind > 0, (e) => e.child(div().text_size(12).text_color(t.muted)
      .child(`${s.behind} commit${s.behind === 1 ? "" : "s"} behind ${row.target}`)))
    .when(s.behind === true, (e) => e.child(div().text_size(12).text_color(t.muted).child(`Behind ${row.target}`)))
    .when(s.autoMerge, (e) => e.child(h_flex().gap(8).items_center()
      .child(div().text_size(12).text_color(t.accent).child("Set to merge when the pipeline succeeds"))
      .child(L.button(t, "rv-auto-cancel", "Cancel auto-merge", (cx) => L.cancelAuto(row, cx), { disabled: busy }))));

  const mergeBox = v_flex().gap(8).p(12).rounded(8).border_1().border_color(t.border)
    .child(h_flex().gap(16).items_center().flex_wrap()
      .child(checkbox(t, "rv-m-squash", "Squash commits", o.squash, (cx) => L.setMergeOpt(row.number, "squash", !o.squash, cx)))
      .child(checkbox(t, "rv-m-del", "Delete source branch", o.removeBranch, (cx) => L.setMergeOpt(row.number, "removeBranch", !o.removeBranch, cx)))
      .child(checkbox(t, "rv-m-auto", gh ? "Auto-merge when checks pass" : "Merge when the pipeline succeeds", o.auto, (cx) => L.setMergeOpt(row.number, "auto", !o.auto, cx), s.autoMerge)))
    .child(h_flex().gap(8).items_center()
      .child(div().flex_1().text_size(11.5).text_color(t.dim)
        .child(canMerge ? (o.auto ? "Merges by itself once the pipeline passes." : `Merges ${row.branch} into ${row.target}.`) : "Fix what's listed above first."))
      .child(L.button(t, "rv-merge", L.confirm === `merge-${row.number}` ? `Merge ${mark}${row.number}? Confirm` : o.auto ? "Set auto-merge" : "Merge",
        (cx) => L.merge(row, o, cx), { primary: true, disabled: busy || !canMerge || s.autoMerge })));

  const people = (what, title, list) => v_flex().gap(4)
    .child(section(t, title))
    .child(h_flex().gap(6).items_center().flex_wrap()
      .children(list.map((x) => h_flex().id(`rv-p-${what}-${x}`).gap(4).px(7).py(1).rounded(10).border_1().border_color(t.border).text_size(11.5)
        .child(div().child(what === "label" ? x : `@${x}`))
        .child(div().id(`rv-p-x-${what}-${x}`).text_color(t.dim).cursor_pointer().on_click((_e, cx) => L.removePerson(row, what, x, list, cx)).child("✕"))))
      .when(L.adding?.what !== what, (e) => e.child(div().id(`rv-p-add-${what}`).px(7).py(1).rounded(10).text_size(11.5).text_color(t.accent).cursor_pointer()
        .on_click((_e, cx) => L.startAdding(row, what, list, cx)).child("+ add")))
      .when(L.adding?.what === what, (e) => e.child(h_flex().id(`rv-p-input-${what}`).w(220).h(26).px(8).items_center().rounded(6).border_1().border_color(t.accent)
        .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
        .child(Input.new(L.peopleInput).flex_1().h_full().text_size(12).text_color(t.foreground)))));

  return v_flex().p(14).gap(12)
    .child(state)
    .when(s.state.startsWith("open"), (e) => e.child(mergeBox))
    .child(people("label", "Labels", s.labels))
    .child(people("assignee", "Assignees", s.assignees))
    .child(people("reviewer", "Reviewers", s.reviewers));
}

// ---- Pipeline: stages and jobs, logs, retry / cancel, ask the agent about a failure ----

export function pipelineView(L, t, row) {
  const p = L.pipes.get(row.number);
  if (!p || p.loading) return div().p(16).text_color(t.dim).child("Loading…");
  if (p.error) return div().p(16).text_size(12).text_color(t.ansi1).child(p.error);
  if (p.none) return div().p(16).text_color(t.dim).child("No pipeline for this request.");
  const busy = Boolean(L.busyAct);
  const [icon, color] = JOB_LOOK[p.status] ?? ["?", "dim"];
  const failed = p.groups.flatMap((g) => g.jobs).filter((j) => j.status === "failed" && !j.allowFailure);

  const head = h_flex().px(14).py(10).gap(10).items_center().border_b(1).border_color(t.border)
    .child(div().text_size(13).text_color(t[color]).child(icon))
    .child(div().text_size(13).font_semibold().child(`Pipeline ${p.status}`))
    .when(Boolean(p.id), (e) => e.child(div().text_size(11).text_color(t.dim).child(`#${p.id}`)))
    .child(div().flex_1())
    .when(failed.length > 0, (e) => e.child(L.button(t, "rv-pl-retry", `Retry failed (${failed.length})`, (cx) => L.retryPipeline(row, p, cx), { disabled: busy })))
    .child(L.button(t, "rv-pl-refresh", "Refresh", (cx) => L.loadPipeline(row, cx, true)))
    .when(Boolean(p.url), (e) => e.child(L.button(t, "rv-pl-open", "Open ↗", () => L.openUrl(p.url))));

  const job = (j, gi, ji) => {
    const [ic, col] = JOB_LOOK[j.status] ?? ["?", "dim"];
    const id = `${gi}-${ji}`;
    const acts = Boolean(j.id) && !j.bridge;
    return h_flex().id(`rv-job-${id}`).h(30).flex_none().px(10).gap(10).items_center().rounded(5).hover((s) => s.bg(t.hover))
      .child(div().w(14).flex_none().text_color(t[col]).child(ic))
      .child(div().flex_1().min_w(0).truncate().text_size(12).child(j.name))
      .when(j.allowFailure && j.status === "failed", (e) => e.child(div().text_size(10.5).text_color(t.dim).child("allowed to fail")))
      .child(div().w(60).flex_none().text_right().text_size(11).text_color(t.dim).child(dur(j.duration)))
      .when(acts && !["manual", "pending", "skipped"].includes(j.status), (e) => e.child(L.button(t, `rv-job-log-${id}`, "Log", (cx) => L.openLog(j, cx))))
      .when(acts && j.status === "failed", (e) => e.child(L.button(t, `rv-job-ai-${id}`, "Ask AI", (cx) => L.askAboutJob(row, j, cx),
        { disabled: busy, tooltip: "Send the end of the log to the agent in this request's review tab" })))
      .when(acts && ["failed", "canceled", "success", "manual"].includes(j.status), (e) => e.child(L.button(t, `rv-job-retry-${id}`,
        j.status === "manual" ? "Run" : "Retry", (cx) => L.jobAction("retry", j, row, cx), { disabled: busy })))
      .when(acts && ["running", "pending"].includes(j.status), (e) => e.child(L.button(t, `rv-job-cancel-${id}`, "Cancel",
        (cx) => L.jobAction("cancel", j, row, cx), { disabled: busy })))
      .when(!acts && Boolean(j.url), (e) => e.child(L.button(t, `rv-job-open-${id}`, "Open ↗", () => L.openUrl(j.url))));
  };

  return v_flex()
    .child(head)
    .children(p.groups.map((g, gi) => v_flex().px(8).pt(8)
      .child(div().px(10).pb(2).text_size(10.5).text_color(t.dim).child(g.name.toUpperCase()))
      .children(g.jobs.map((j, ji) => job(j, gi, ji)))));
}
