import { test } from "node:test";
import assert from "node:assert/strict";
import claude from "../providers/claude.js";
import { NOW, read, claudeReply } from "./_util.js";

test("descriptor", () => {
  assert.equal(claude.id, "claude");
  assert.equal(claude.name, "Claude");
  assert.equal(claude.icon, "icons/claude.svg");
  assert.equal(claude.helper, "helpers/claude-usage.sh");
});

test("max fixture → three windows in order", () => {
  const r = claude.parse(read("claude-get-usage.max.json"), NOW);
  assert.equal(r.status, "ok");
  assert.equal(r.plan, "max");
  assert.equal(r.source, "claude CLI");
  assert.equal(r.observedAt, NOW);
  assert.deepEqual(r.windows.map((w) => [w.id, w.short, w.long, w.percent]), [
    ["session", "5h", "5-hour", 6],
    ["weekly_all", "wk", "Weekly", 50],
    ["weekly_scoped:Fable", "Fable", "Weekly · Fable", 3],
  ]);
  assert.equal(r.windows[0].resetsAt, Math.floor(Date.parse("2026-11-04T09:00:00.643974+00:00") / 1000));
  assert.deepEqual(r.windows.map((w) => w.durationSec), [18000, 604800, 604800]);
});

test("unknown kind → generic label, no duration", () => {
  const r = claude.parse(claudeReply({ limits: [{ kind: "monthly_thing", percent: 7.4, resets_at: null, scope: null }] }), NOW);
  assert.deepEqual(r.windows, [{ id: "monthly_thing", short: "monthly thing", long: "monthly thing", percent: 7, resetsAt: null, durationSec: null }]);
});

test("scope.surface used when no model", () => {
  const r = claude.parse(claudeReply({ limits: [{ kind: "weekly_scoped", percent: 9, resets_at: null, scope: { model: null, surface: "Cowork" } }] }), NOW);
  assert.equal(r.windows[0].id, "weekly_scoped:Cowork");
  assert.equal(r.windows[0].short, "Cowork");
  assert.equal(r.windows[0].long, "Weekly · Cowork");
});

test("error reply → status error, no windows", () => {
  const r = claude.parse(read("claude-get-usage.error.json"), NOW);
  assert.equal(r.status, "error");
  assert.deepEqual(r.windows, []);
  assert.match(r.message, /Not logged in/);
});

test("api-key reply → unavailable 'No subscription limits', no windows", () => {
  const r = claude.parse(read("claude-get-usage.apikey.json"), NOW);
  assert.equal(r.status, "unavailable");
  assert.equal(r.message, "No subscription limits");
  assert.deepEqual(r.windows, []);
});

test("legacy reply → 5h 12 and wk 34 from utilization", () => {
  const r = claude.parse(read("claude-get-usage.legacy.json"), NOW);
  assert.deepEqual(r.windows.map((w) => [w.id, w.short, w.percent, w.durationSec]), [
    ["session", "5h", 12, 18000],
    ["weekly_all", "wk", 34, 604800],
  ]);
});

test("garbage text → status error", () => {
  assert.equal(claude.parse("not json", NOW).status, "error");
  assert.equal(claude.parse("", NOW).status, "error");
});

test("finds control_response among other lines", () => {
  const text = 'Welcome\n{"type":"system","subtype":"init"}\n' + read("claude-get-usage.max.json") + "\n";
  assert.equal(claude.parse(text, NOW).windows.length, 3);
});
