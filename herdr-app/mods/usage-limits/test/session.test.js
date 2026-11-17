import { test } from "node:test";
import assert from "node:assert/strict";
import { AGENT_NAMES, parseSession, sessionView, sessionOnBar } from "../lib/session.js";

const CODEX = "tokens=115225 window=475000 calls=4\n";
const CLAUDE = "tokens=182010 calls=32 compactions=2 lastTrigger=auto lastPre=259912 lastPost=10364\n";

test("parseSession: reads the helper's line", () => {
  assert.deepEqual(parseSession(CODEX, "codex"), { app: "codex", tokens: 115225, window: 475000, calls: 4, compactions: null, last: null });
  assert.deepEqual(parseSession(CLAUDE, "claude"), { app: "claude", tokens: 182010, window: null, calls: 32, compactions: 2, last: { trigger: "auto", pre: 259912, post: 10364 } });
});

test("parseSession: no compaction yet has a count of 0 and no last", () => {
  const s = parseSession("tokens=5 calls=1 compactions=0\n", "claude");
  assert.deepEqual([s.compactions, s.last], [0, null]);
});

test("parseSession: nothing usable is null, never zeros", () => {
  assert.equal(parseSession("", "claude"), null);
  assert.equal(parseSession("garbage\n", "claude"), null);
  assert.equal(parseSession("calls=3\n", "claude"), null);
});

test("sessionView: a known window gives a percent, bar and level", () => {
  const v = sessionView(parseSession(CODEX, "codex"), "herdr");
  assert.equal(v.title, "herdr");
  assert.deepEqual(v.context, { text: "24%", detail: "115k of 475k", fill: 115225 / 475000, level: "ok" });
  assert.equal(v.calls, "4 calls");
});

test("sessionView: a nearly full window warns", () => {
  const s = { app: "codex", tokens: 450000, window: 475000, calls: 1, compactions: null, last: null };
  assert.equal(sessionView(s, "x").context.level, "hot");
});

test("sessionView: an unknown window shows tokens, no made-up percent", () => {
  const v = sessionView(parseSession(CLAUDE, "claude"), "x");
  assert.deepEqual(v.context, { text: "182k", detail: null, fill: null, level: "ok" });
});

test("sessionView: compactions spell out the last one", () => {
  const v = sessionView(parseSession(CLAUDE, "claude"), "x");
  assert.equal(v.compactions, "2 compactions");
  assert.equal(v.last, "last: auto, 260k → 10k");
});

test("sessionView: singular and zero read right", () => {
  const v = sessionView({ app: "claude", tokens: 1, window: null, calls: 1, compactions: 1, last: null }, "x");
  assert.deepEqual([v.calls, v.compactions], ["1 call", "1 compaction"]);
  assert.equal(sessionView({ app: "claude", tokens: 1, window: null, calls: 0, compactions: 0, last: null }, "x").compactions, "0 compactions");
});

test("sessionView: Codex has no compaction line rather than a false 0", () => {
  const v = sessionView(parseSession(CODEX, "codex"), "x");
  assert.deepEqual([v.compactions, v.last], [null, null]);
});

test("sessionView: Codex's measured compactions appear in the panel and bar", () => {
  const s = parseSession("tokens=12345 window=475000 calls=8 compactions=2", "codex");
  assert.equal(sessionView(s, "project").compactions, "2 compactions");
  assert.deepEqual(sessionOnBar(s, { sessionOnBar: ["compactions"] }), [{ id: "compactions", text: "▼ 2", level: "ok" }]);
});

test("sessionView: no session means no block", () => {
  assert.equal(sessionView(null, "x"), null);
});

const onBar = (...rows) => ({ sessionOnBar: rows });

test("sessionOnBar: nothing unless ticked", () => {
  assert.deepEqual(sessionOnBar(parseSession(CLAUDE, "claude"), onBar()), []);
  assert.deepEqual(sessionOnBar(null, onBar("context", "calls")), []);
});

test("sessionOnBar: the ticked numbers, in a fixed order", () => {
  assert.deepEqual(sessionOnBar(parseSession(CLAUDE, "claude"), onBar("compactions", "context", "calls")), [
    { id: "context", text: "ctx 182k", level: "ok" },
    { id: "calls", text: "⇄ 32", level: "ok" },
    { id: "compactions", text: "▼ 2", level: "ok" },
  ]);
});

test("sessionOnBar: a known window shows a percent, and warns", () => {
  assert.deepEqual(sessionOnBar(parseSession(CODEX, "codex"), onBar("context")), [{ id: "context", text: "ctx 24%", level: "ok" }]);
  const full = { app: "codex", tokens: 450000, window: 475000, calls: 1, compactions: null, last: null };
  assert.equal(sessionOnBar(full, onBar("context"))[0].level, "hot");
});

test("sessionOnBar: Codex has no compaction number rather than a false 0", () => {
  assert.deepEqual(sessionOnBar(parseSession(CODEX, "codex"), onBar("compactions")), []);
});

test("pi: who names the agent and the model; claude and codex have none", () => {
  const s = parseSession("tokens=50500 calls=3 model=demo-model", "pi");
  assert.equal(s.model, "demo-model");
  assert.equal(sessionView(s, "project").who, "Pi · demo-model");
  assert.equal(sessionView(parseSession("tokens=50500 calls=3", "pi"), "p").who, "Pi");
  assert.equal(sessionView(parseSession("tokens=9 calls=1 compactions=0", "claude"), "p").who, null);
  assert.equal(sessionView(parseSession(CODEX, "codex"), "p").who, null);
});

test("pi: a model id the helper would never print is not shown", () => {
  assert.equal(parseSession("tokens=5 calls=1 model=bad;id", "pi").model, null);
  assert.equal(AGENT_NAMES.pi, "Pi");
  assert.equal(AGENT_NAMES.opencode, "OpenCode");
});
