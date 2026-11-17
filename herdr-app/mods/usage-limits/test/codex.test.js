import { test } from "node:test";
import assert from "node:assert/strict";
import codex from "../providers/codex.js";
import { PROVIDERS } from "../providers/index.js";
import { NOW, read } from "./_util.js";

test("descriptor and registry", () => {
  assert.equal(codex.id, "codex");
  assert.equal(codex.icon, "icons/codex.svg");
  assert.equal(codex.helper, "helpers/codex-limits.sh");
  assert.deepEqual(PROVIDERS.map((p) => p.id), ["claude", "codex", "opencode", "pi"]);
});

test("plus fixture → 5h 0, wk 11 with durations from windowDurationMins", () => {
  const r = codex.parse(read("codex-app-server.plus.json"), NOW);
  assert.equal(r.status, "ok");
  assert.deepEqual(r.windows.map((w) => [w.id, w.short, w.percent, w.durationSec]), [
    ["codex:primary", "5h", 0, 18000],
    ["codex:secondary", "wk", 11, 604800],
  ]);
  assert.deepEqual(r.windows.map((w) => w.long), ["5-hour", "Weekly"]);
  assert.equal(r.windows[1].resetsAt, 1793944050);
  assert.equal(r.plan, "plus");
  assert.equal(r.source, "codex app-server");
  assert.equal(r.observedAt, NOW);
});

test("multi limit ids → codex first, then 'Spark 5h'", () => {
  const r = codex.parse(read("codex-app-server.multi.json"), NOW);
  assert.deepEqual(r.windows.map((w) => w.id), ["codex:primary", "codex:secondary", "spark:primary"]);
  assert.equal(r.windows[2].short, "Spark 5h");
  assert.equal(r.windows[2].long, "Spark · 5-hour");
  assert.equal(r.windows[2].percent, 40);
});

test("session snapshot fallback → error with the snapshot as a dated fallback", () => {
  const text = read("codex-session-snapshot.json");
  const snap = JSON.parse(text).snapshot;
  const r = codex.parse(text, NOW);
  assert.equal(r.status, "error");
  assert.equal(r.message, "Codex app-server didn't answer");
  assert.deepEqual(r.windows, []);
  assert.equal(r.fallback.status, "ok");
  assert.equal(r.fallback.source, "Codex session log");
  assert.equal(r.fallback.observedAt, Math.floor(Date.parse(snap.timestamp) / 1000));
  assert.deepEqual(r.fallback.windows.map((w) => w.id), ["codex:primary", "codex:secondary"]);
  assert.equal(r.fallback.windows[0].percent, Math.round(snap.payload.rate_limits.primary.used_percent));
});

test("snapshot without a timestamp → no fallback (never stamped as fresh)", () => {
  const snap = JSON.parse(read("codex-session-snapshot.json")).snapshot;
  delete snap.timestamp;
  const r = codex.parse(JSON.stringify({ snapshot: snap }), NOW);
  assert.equal(r.status, "error");
  assert.equal(r.fallback, undefined);
});

test("garbage → status error", () => {
  assert.equal(codex.parse("{}", NOW).status, "error");
  assert.equal(codex.parse("nope", NOW).status, "error");
});
