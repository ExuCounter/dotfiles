import { test } from "node:test";
import assert from "node:assert/strict";
import { nextState } from "../lib/state.js";

const NOW = 1793779000;
const ok = (at, pct = 10) => ({ status: "ok", message: null, plan: null, observedAt: at, source: "s", windows: [{ id: "w", short: "wk", long: "Weekly", percent: pct, resetsAt: null, durationSec: null }] });
const err = (fallback) => ({ status: "error", message: "x", plan: null, observedAt: NOW, source: "s", windows: [], ...(fallback ? { fallback } : {}) });
const EMPTY = { report: null, lastGood: null, installed: null };

test("ok report becomes lastGood", () => {
  const s = nextState(EMPTY, ok(NOW), true);
  assert.equal(s.lastGood.observedAt, NOW);
  assert.equal(s.installed, true);
});

test("error keeps the previous lastGood", () => {
  const prev = { report: ok(NOW - 300), lastGood: ok(NOW - 300), installed: true };
  const s = nextState(prev, err(), true);
  assert.equal(s.report.status, "error");
  assert.equal(s.lastGood.observedAt, NOW - 300);
});

test("an older fallback never replaces a fresher lastGood", () => {
  const prev = { report: ok(NOW - 300, 50), lastGood: ok(NOW - 300, 50), installed: true };
  const s = nextState(prev, err(ok(NOW - 2 * 86400, 3)), true);
  assert.equal(s.lastGood.observedAt, NOW - 300);
  assert.equal(s.lastGood.windows[0].percent, 50);
});

test("a fallback fills lastGood when there is nothing fresher", () => {
  const s = nextState(EMPTY, err(ok(NOW - 3600, 7)), true);
  assert.equal(s.report.status, "error", "still shown as failing ('!')");
  assert.equal(s.lastGood.observedAt, NOW - 3600);
});

test("not installed keeps lastGood but no report", () => {
  const prev = { report: ok(NOW - 300), lastGood: ok(NOW - 300), installed: true };
  assert.deepEqual(nextState(prev, null, false), { report: null, lastGood: prev.lastGood, installed: false });
});
