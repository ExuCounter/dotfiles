import { test } from "node:test";
import assert from "node:assert/strict";
import { effectivePrefs, inPanel, isFolded, isOnBar, isShown, spendOnBar, toggleFolded, toggleOnBar, togglePanel, toggleProvider, toggleShowBars, toggleShowResetTime, toggleSpendOnBar, toggleWindow } from "../lib/prefs.js";

test("layout presets apply until saved prefs exist", () => {
  const props = { hidden: ["codex"], hiddenWindows: ["claude:session"] };
  assert.deepEqual(effectivePrefs(null, props), { hidden: ["codex"], hiddenWindows: ["claude:session"], showResetTime: false, showBars: true, sessionOnBar: [], panelHidden: [], folded: [], spendOnBar: {} });
  assert.deepEqual(effectivePrefs({ hidden: [], hiddenWindows: [] }, props), { hidden: [], hiddenWindows: [], showResetTime: false, showBars: true, sessionOnBar: [], panelHidden: [], folded: [], spendOnBar: {} });
  assert.deepEqual(effectivePrefs(null, {}), { hidden: [], hiddenWindows: [], showResetTime: false, showBars: true, sessionOnBar: [], panelHidden: [], folded: [], spendOnBar: {} });
  assert.deepEqual(effectivePrefs(undefined, undefined), { hidden: [], hiddenWindows: [], showResetTime: false, showBars: true, sessionOnBar: [], panelHidden: [], folded: [], spendOnBar: {} });
});

test("anything not listed is shown, including new windows", () => {
  const p = { hidden: ["codex"], hiddenWindows: ["claude:session"] };
  assert.equal(isShown(p, "claude"), true);
  assert.equal(isShown(p, "codex"), false);
  assert.equal(isShown(p, "claude", "session"), false);
  assert.equal(isShown(p, "claude", "weekly_scoped:Opus"), true);
  assert.equal(isShown(p, "codex", "codex:primary"), false, "window of a hidden provider");
});

test("toggles round-trip and don't mutate", () => {
  const p0 = { hidden: [], hiddenWindows: [] };
  const p1 = toggleProvider(p0, "codex");
  assert.deepEqual(p1.hidden, ["codex"]);
  assert.deepEqual(p0.hidden, []);
  assert.deepEqual(toggleProvider(p1, "codex").hidden, []);
  const p2 = toggleWindow(p0, "claude", "weekly_scoped:Fable");
  assert.deepEqual(p2.hiddenWindows, ["claude:weekly_scoped:Fable"]);
  assert.deepEqual(toggleWindow(p2, "claude", "weekly_scoped:Fable").hiddenWindows, []);
});

test("reset time is off by default and a layout can preset it", () => {
  assert.equal(effectivePrefs(null, {}).showResetTime, false);
  assert.equal(effectivePrefs(null, { showResetTime: true }).showResetTime, true);
  assert.equal(effectivePrefs({ hidden: [], hiddenWindows: [] }, { showResetTime: true }).showResetTime, false, "saved prefs win");
});

test("toggleShowResetTime round-trips and doesn't mutate", () => {
  const p0 = { hidden: ["codex"], hiddenWindows: [], showResetTime: false };
  const p1 = toggleShowResetTime(p0);
  assert.equal(p1.showResetTime, true);
  assert.equal(p0.showResetTime, false);
  assert.deepEqual(p1.hidden, ["codex"]);
  assert.equal(toggleShowResetTime(p1).showResetTime, false);
});

test("hiding a provider or window keeps the reset time choice", () => {
  const p = { hidden: [], hiddenWindows: [], showResetTime: true };
  assert.equal(toggleProvider(p, "codex").showResetTime, true);
  assert.equal(toggleWindow(p, "claude", "session").showResetTime, true);
});

test("session numbers stay off the bar until ticked, and a layout can preset them", () => {
  assert.equal(isOnBar(effectivePrefs(null, {}), "context"), false);
  assert.equal(isOnBar(effectivePrefs(null, { sessionOnBar: ["calls"] }), "calls"), true);
});

test("toggleOnBar round-trips and doesn't mutate", () => {
  const p0 = effectivePrefs(null, {});
  const p1 = toggleOnBar(p0, "calls");
  assert.equal(isOnBar(p1, "calls"), true);
  assert.equal(isOnBar(p0, "calls"), false);
  assert.equal(isOnBar(toggleOnBar(p1, "calls"), "calls"), false);
});

test("every toggle keeps the other choices", () => {
  const p = { hidden: ["codex"], hiddenWindows: ["a:b"], showResetTime: true, sessionOnBar: ["calls"] };
  for (const q of [toggleProvider(p, "x"), toggleWindow(p, "x", "y"), toggleShowResetTime(p)]) assert.deepEqual(q.sessionOnBar, ["calls"]);
  assert.equal(toggleOnBar(p, "context").showResetTime, true);
});

test("bars show until switched off, and old saved prefs keep them", () => {
  assert.equal(effectivePrefs({ hidden: [], hiddenWindows: [] }, null).showBars, true);
  assert.equal(effectivePrefs({ showBars: false }, null).showBars, false);
});

test("toggleShowBars flips only that choice", () => {
  const p = effectivePrefs({ hidden: ["codex"] }, null);
  const off = toggleShowBars(p);
  assert.deepEqual(off, { ...p, showBars: false });
  assert.equal(toggleShowBars(off).showBars, true);
});

test("old prefs: nothing folded, everything in the panel, no spend choice", () => {
  const p = effectivePrefs({ hidden: ["codex"], hiddenWindows: ["claude:session"] }, undefined);
  assert.deepEqual([p.panelHidden, p.folded, p.spendOnBar], [[], [], {}]);
  assert.equal(inPanel(p, "codex"), true);       // hidden still means the bar only
  assert.equal(inPanel(p, "session"), true);
  assert.equal(isFolded(p, "claude"), false);
  assert.equal(isShown(p, "codex"), false);
});
test("panel, fold and spend choices flip and keep the rest", () => {
  let p = effectivePrefs({ hidden: ["codex"], showResetTime: true }, undefined);
  p = togglePanel(p, "claude"); p = togglePanel(p, "session"); p = toggleFolded(p, "codex");
  assert.equal(inPanel(p, "claude"), false);
  assert.equal(inPanel(p, "session"), false);
  assert.equal(isFolded(p, "codex"), true);
  assert.deepEqual([p.hidden, p.showResetTime], [["codex"], true]);
  assert.equal(inPanel(togglePanel(p, "claude"), "claude"), true);
});
test("spend on the bar: default until chosen, then the choice wins", () => {
  const p = effectivePrefs(null, undefined);
  assert.equal(spendOnBar(p, "opencode", false), false);
  assert.equal(spendOnBar(p, "opencode", true), true);
  const on = toggleSpendOnBar(p, "opencode", false);
  assert.equal(spendOnBar(on, "opencode", false), true);
  assert.equal(spendOnBar(toggleSpendOnBar(on, "opencode", true), "opencode", true), false);
});
test("every existing toggle keeps the new keys", () => {
  const p = toggleFolded(togglePanel(effectivePrefs(null, undefined), "pi"), "claude");
  for (const q of [toggleProvider(p, "codex"), toggleWindow(p, "claude", "session"), toggleShowResetTime(p), toggleShowBars(p), toggleOnBar(p, "calls")]) {
    assert.deepEqual([q.panelHidden, q.folded], [["pi"], ["claude"]]);
  }
});
