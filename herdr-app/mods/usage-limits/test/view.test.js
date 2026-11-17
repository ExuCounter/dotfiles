process.env.TZ = "UTC";
import { test } from "node:test";
import assert from "node:assert/strict";
import { segmentView } from "../lib/view.js";
import claude from "../providers/claude.js";
import { read } from "./_util.js";

const NOW = Date.UTC(2026, 10, 4, 8, 0, 0) / 1000;
const W = (o) => ({ id: "x", short: "wk", long: "Weekly", percent: 50, resetsAt: NOW + 58 * 3600, durationSec: 604800, ...o });

test("ok segment: percent only, fill and tick", () => {
  const s = segmentView(W(), NOW);
  assert.equal(s.text, "50%");
  assert.equal(s.level, "ok");
  assert.equal(s.fill, 0.5);
  assert.ok(Math.abs(s.tick - 0.6548) < 0.001);
  assert.equal(s.expired, false);
  assert.equal(s.short, "wk");
});

test("hot segment appends time to reset", () => {
  const s = segmentView(W({ percent: 92, resetsAt: NOW + 38 * 60, durationSec: 18000 }), NOW);
  assert.equal(s.text, "92% · 38m");
  assert.equal(s.level, "hot");
});

test("warn segment appends time to reset", () => {
  assert.equal(segmentView(W({ percent: 74 }), NOW).text, "74% · 2d 10h");
});

test("segment of a passed window is '—' with no tick", () => {
  const s = segmentView(W({ percent: 95, resetsAt: NOW - 1 }), NOW);
  assert.deepEqual([s.text, s.fill, s.tick, s.level, s.expired], ["—", 0, null, "ok", true]);
});

test("fill is clamped to 0–1", () => {
  assert.equal(segmentView(W({ percent: 130 }), NOW).fill, 1);
});

// ---- barModel / chooseDensity (Task 4) ----
import { barModel, cardModel, chooseDensity, panelOnEnter } from "../lib/view.js";
import codex from "../providers/codex.js";

const PREFS = { hidden: [], hiddenWindows: [] };
const ok = (p, file, at = NOW) => ({ ...p.parse(read(file), at), observedAt: at });
const STATES = () => ({
  claude: { report: ok(claude, "claude-get-usage.max.json"), lastGood: ok(claude, "claude-get-usage.max.json"), installed: true },
  codex: { report: ok(codex, "codex-app-server.plus.json"), lastGood: ok(codex, "codex-app-server.plus.json"), installed: true },
});

test("barModel: both providers, all windows, in registry order", () => {
  const m = barModel(STATES(), PREFS, NOW);
  assert.equal(m.empty, false);
  assert.deepEqual(m.groups.map((g) => [g.providerId, g.name, g.icon, g.mark, g.dim]), [
    ["claude", "Claude", "icons/claude.svg", null, false],
    ["codex", "Codex", "icons/codex.svg", null, false],
  ]);
  assert.deepEqual(m.groups[0].segments.map((s) => s.short), ["5h", "wk", "Fable"]);
});

test("barModel: hidden provider and hidden window are dropped", () => {
  const m = barModel(STATES(), { hidden: ["codex"], hiddenWindows: ["claude:session"] }, NOW);
  assert.deepEqual(m.groups.map((g) => g.providerId), ["claude"]);
  assert.deepEqual(m.groups[0].segments.map((s) => s.id), ["weekly_all", "weekly_scoped:Fable"]);
});

test("barModel: failing provider keeps last good reading, dimmed, with '!'", () => {
  const s = STATES();
  s.claude.report = { status: "error", message: "offline", plan: null, observedAt: NOW, source: "claude CLI", windows: [] };
  const g = barModel(s, PREFS, NOW).groups[0];
  assert.deepEqual([g.mark, g.dim, g.segments.length], ["!", true, 3]);
});

test("barModel: failing provider with no last reading → '!' and no segments", () => {
  const s = STATES();
  s.codex = { report: { status: "error", message: "x", plan: null, observedAt: NOW, source: "s", windows: [] }, lastGood: null, installed: true };
  const g = barModel(s, PREFS, NOW).groups[1];
  assert.deepEqual([g.mark, g.segments.length], ["!", 0]);
});

test("barModel: not installed → absent; loading → '…'", () => {
  const s = STATES();
  s.codex = { report: null, lastGood: null, installed: false };
  s.claude = { report: null, lastGood: null, installed: null };
  const m = barModel(s, PREFS, NOW);
  assert.deepEqual(m.groups.map((g) => [g.providerId, g.mark, g.segments.length]), [["claude", "…", 0]]);
});

test("barModel: reading older than 15 min is dimmed", () => {
  const s = STATES();
  s.codex.report = { ...s.codex.report, observedAt: NOW - 901 };
  assert.equal(barModel(s, PREFS, NOW).groups[1].dim, true);
});

test("barModel: everything hidden → empty", () => {
  assert.equal(barModel(STATES(), { hidden: ["claude", "codex"], hiddenWindows: [] }, NOW).empty, true);
  assert.equal(barModel({}, PREFS, NOW).empty, false, "unknown state = loading groups");
});

test("chooseDensity: full at 600px, no bars at 400px, percents only at 140px", () => {
  const m = barModel(STATES(), PREFS, NOW);
  assert.equal(chooseDensity(m, 600), 0);
  assert.equal(chooseDensity(m, 400), 1);
  assert.equal(chooseDensity(m, 140), 3);
});

// ---- reset time always on ----

test("chooseDensity: with bars off it never picks the bars, and still narrows", () => {
  const m = barModel(STATES(), PREFS, NOW);
  assert.equal(chooseDensity(m, 600, false), 1);
  assert.equal(chooseDensity(m, 140, false), chooseDensity(m, 140));
});

test("showResetTime: a calm window shows its time too", () => {
  assert.equal(segmentView(W(), NOW, true).text, "50% · 2d 10h");
});

test("showResetTime off: a calm window stays percent only", () => {
  assert.equal(segmentView(W(), NOW, false).text, "50%");
});

test("brief drops the time of a calm window only", () => {
  assert.equal(segmentView(W(), NOW, true).brief, "50%");
  assert.equal(segmentView(W({ percent: 74 }), NOW, true).brief, "74% · 2d 10h");
});

test("showResetTime: no reset known, or already passed, adds no time", () => {
  assert.equal(segmentView(W({ resetsAt: null }), NOW, true).text, "50%");
  const s = segmentView(W({ resetsAt: NOW - 1 }), NOW, true);
  assert.deepEqual([s.text, s.brief], ["—", "—"]);
});

test("barModel: applies showResetTime from prefs", () => {
  const texts = (prefs) => barModel(STATES(), prefs, NOW).groups[0].segments.map((s) => s.text);
  assert.ok(texts({ ...PREFS, showResetTime: true }).every((t) => t.includes(" · ")));
  assert.ok(!texts(PREFS).some((t) => t.includes(" · ")));
});

test("chooseDensity: times of calm windows go last, so providers still fit", () => {
  const on = barModel(STATES(), { ...PREFS, showResetTime: true }, NOW);
  assert.equal(chooseDensity(on, 2000), 0);
  assert.equal(chooseDensity(on, 300), 3);
});

// ---- hover card ----

test("cardModel: a provider's plan, age and one row per window", () => {
  const s = STATES();
  s.claude.report = { ...s.claude.report, observedAt: NOW - 60 };
  const g = cardModel(s, NOW).groups[0];
  assert.deepEqual([g.providerId, g.name, g.plan, g.status, g.failed, g.dim], ["claude", "Claude", "Max", "updated just now", false, false]);
  assert.deepEqual(g.rows.map((r) => r.long), ["5-hour", "Weekly", "Weekly · Fable"]);
});

test("cardModel: a row carries percent, level, bar and time left, on one line", () => {
  const report = { status: "ok", plan: "max", observedAt: NOW, source: "x", windows: [W({ percent: 74, resetsAt: NOW + 58 * 3600 })] };
  const r = cardModel({ claude: { report, lastGood: report, installed: true } }, NOW, [claude]).groups[0].rows[0];
  assert.deepEqual([r.percent, r.level, r.fill], ["74%", "warn", 0.74]);
  assert.ok(Math.abs(r.tick - 0.6548) < 0.001);
  assert.equal(r.left, "2d 10h");
  assert.equal(r.detail, "");
});

const hintFor = (w) => {
  const report = { status: "ok", plan: null, observedAt: NOW, source: "x", windows: [W(w)] };
  return cardModel({ claude: { report, lastGood: report, installed: true } }, NOW, [claude]).groups[0].rows[0].hint;
};

test("cardModel: a row's hint explains its tick with its own numbers", () => {
  const left = { resetsAt: NOW + 58 * 3600 }; // 65% of a week gone
  assert.equal(hintFor({ percent: 70, ...left }), "Tick: 65% of the time has passed.\nYou've used 70%, so you're on pace.");
  assert.equal(hintFor({ percent: 92, ...left }), "Tick: 65% of the time has passed.\nYou've used 92%, so you're using it up too fast.");
  assert.equal(hintFor({ percent: 20, ...left }), "Tick: 65% of the time has passed.\nYou've used 20%, so you have room to spare.");
});

test("cardModel: no tick, no hint", () => {
  assert.equal(hintFor({ resetsAt: null, durationSec: null }), null);
  assert.equal(hintFor({ percent: 95, resetsAt: NOW - 1 }), null);
});

test("cardModel: a row with no known reset has no time left", () => {
  const report = { status: "ok", plan: null, observedAt: NOW, source: "x", windows: [W({ resetsAt: null, durationSec: null })] };
  const g = cardModel({ claude: { report, lastGood: report, installed: true } }, NOW, [claude]).groups[0];
  assert.equal(g.plan, null);
  assert.deepEqual([g.rows[0].left, g.rows[0].detail], ["", ""]);
});

test("cardModel: a passed reset shows '—', never a number", () => {
  const report = { status: "ok", plan: null, observedAt: NOW, source: "x", windows: [W({ percent: 95, resetsAt: NOW - 1 })] };
  const r = cardModel({ claude: { report, lastGood: report, installed: true } }, NOW, [claude]).groups[0].rows[0];
  assert.deepEqual([r.percent, r.level, r.fill, r.tick, r.left, r.detail], ["—", "ok", 0, null, "", "reset, waiting for a new reading"]);
});

test("cardModel: not installed providers are left out", () => {
  const s = STATES();
  s.codex = { report: null, lastGood: null, installed: false };
  assert.deepEqual(cardModel(s, NOW).groups.map((g) => g.providerId), ["claude"]);
});

test("cardModel: nothing installed means no limits to show", () => {
  const gone = { report: null, lastGood: null, installed: false };
  assert.equal(cardModel({ claude: gone, codex: gone }, NOW).empty, true);
});

test("cardModel: a failing provider says why and keeps its last reading, dimmed, with its age", () => {
  const s = STATES();
  s.claude.lastGood = { ...s.claude.lastGood, observedAt: NOW - 1200 };
  s.claude.report = { status: "error", message: "Not logged in", plan: null, observedAt: NOW, source: "claude CLI", windows: [] };
  const g = cardModel(s, NOW).groups[0];
  assert.deepEqual([g.status, g.failed, g.dim, g.age, g.rows.length], ["Not logged in", true, true, "Last reading 20 min ago", 3]);
});

test("cardModel: a failing provider with no last reading has no rows", () => {
  const s = STATES();
  s.claude = { report: { status: "error", message: "offline", plan: null, observedAt: NOW, source: "x", windows: [] }, lastGood: null, installed: true };
  const g = cardModel(s, NOW).groups[0];
  assert.deepEqual([g.status, g.failed, g.age, g.rows.length], ["offline", true, null, 0]);
});

test("cardModel: a provider still loading says so", () => {
  const g = cardModel({}, NOW).groups[0];
  assert.deepEqual([g.status, g.failed, g.rows.length], ["loading…", false, 0]);
});

test("cardModel: a reading older than 15 min is dimmed", () => {
  const s = STATES();
  s.codex.report = { ...s.codex.report, observedAt: NOW - 901 };
  const g = cardModel(s, NOW).groups[1];
  assert.equal(g.dim, true);
  assert.equal(g.status, "updated 15 min ago");
});

// ---- which side of the panel shows ----

test("panelOnEnter: settings stay while the pointer only crosses the gap", () => {
  assert.equal(panelOnEnter("settings", 1000, 1200, 300), "settings");
});

test("panelOnEnter: back to limits once the panel has closed", () => {
  assert.equal(panelOnEnter("settings", 1000, 1301, 300), "limits");
});

test("panelOnEnter: settings stay if the pointer never left", () => {
  assert.equal(panelOnEnter("settings", null, 5000, 300), "settings");
});

test("panelOnEnter: limits stay limits", () => {
  assert.equal(panelOnEnter("limits", 1000, 9000, 300), "limits");
});

// ---- spend, folds and panel visibility ----
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { tightest, hasLimits, limitsSettled, wanted } from "../lib/view.js";
import { okReport, errorReport, unavailableReport, spendReport, makeWindow } from "../lib/report.js";
import { PROVIDERS } from "../providers/index.js";
import { scenarios, NOW as SNAP_NOW } from "./_view-scenarios.js";
import { HERE } from "./_util.js";

const OC = { id: "opencode", name: "OpenCode", icon: "i", kind: "spend" };
const WITH_SPEND = [claude, codex, OC];
const DEFAULTS = { hidden: [], hiddenWindows: [] };
const win = (id, percent, resetsAt, durationSec = 18000) => makeWindow({ id, short: id, long: `Long ${id}`, percent, resetsAt, durationSec });
const lim = (windows, at = NOW) => ({ report: okReport("x", at, windows, "pro"), lastGood: okReport("x", at, windows, "pro"), installed: true });
const spend = (today, week, at = NOW) => ({ report: spendReport("y", at, today, week), lastGood: spendReport("y", at, today, week), installed: true });
const NONE = { report: null, lastGood: null, installed: null };
const GONE = { report: null, lastGood: null, installed: false };
const strip = (m) => {
  const { arrows, ...rest } = m;
  assert.equal(typeof arrows, "boolean");
  return { ...rest, groups: rest.groups.map(({ kind, folded, summary, ...g }) => (assert.equal(kind, "limits"), assert.equal(folded, false), g)) };
};

test("spendReport: ok, no windows, today and week", () => {
  assert.deepEqual(spendReport("opencode stats", 100, 1200, 34000, 90), {
    status: "ok", message: null, plan: null, observedAt: 90, source: "opencode stats", windows: [], spend: { today: 1200, week: 34000 },
  });
  assert.equal(spendReport("s", 100, 0, 0).observedAt, 100);
});

test("tightest: highest percent, ties to the sooner reset, a passed reset loses", () => {
  assert.equal(tightest([], NOW), null);
  assert.equal(tightest([win("a", 40, NOW + 600), win("b", 70, NOW + 9000)], NOW).id, "b");
  assert.equal(tightest([win("a", 70, NOW + 9000), win("b", 70, NOW + 600)], NOW).id, "b");
  assert.equal(tightest([win("a", 70, null), win("b", 70, NOW + 600)], NOW).id, "b", "an unknown reset is later than a known one");
  assert.equal(tightest([win("a", 99, NOW - 1), win("b", 5, NOW + 600)], NOW).id, "b");
  assert.equal(tightest([win("a", 99, NOW - 1)], NOW).id, "a", "the only one is the tightest");
});

test("card: default prefs give today's groups, plus kind/folded/summary", () => {
  const before = JSON.parse(readFileSync(join(HERE, "fixtures", "view-before.json"), "utf8"));
  for (const [name, mk] of Object.entries(scenarios)) {
    for (const providers of [[claude, codex], WITH_SPEND, PROVIDERS]) {
      assert.deepEqual(strip(cardModel(mk(), SNAP_NOW, providers)), before[name].card, `${name} card, ${providers.length} providers`);
      assert.deepEqual(barModel(mk(), DEFAULTS, SNAP_NOW, providers), before[name].bar, `${name} bar, ${providers.length} providers`);
    }
  }
});

test("card: a limits provider with no state still loads, a spend one with no state is absent", () => {
  const m = cardModel({}, NOW, WITH_SPEND);
  assert.deepEqual(m.groups.map((g) => [g.providerId, g.status, g.summary]), [["claude", "loading…", null], ["codex", "loading…", null]]);
  assert.deepEqual(barModel({}, DEFAULTS, NOW, WITH_SPEND).groups.map((g) => [g.providerId, g.mark]), [["claude", "…"], ["codex", "…"]]);
  assert.deepEqual(cardModel({ opencode: NONE }, NOW, [OC]).groups, []);
});

test("card: a folded group carries its tightest row as summary and keeps its rows", () => {
  const s = { claude: lim([win("5h", 30, NOW + 3600), win("wk", 91, NOW + 7200, 604800)]) };
  const g = cardModel(s, NOW, [claude], { ...DEFAULTS, folded: ["claude"] }).groups[0];
  assert.deepEqual([g.kind, g.folded, g.rows.length], ["limits", true, 2]);
  assert.deepEqual([g.summary.id, g.summary.long, g.summary.percent, g.summary.level, g.summary.left], ["wk", "Long wk", "91%", "hot", "2h 0m"]);
  assert.deepEqual(g.summary, g.rows[1]);
  const open = cardModel(s, NOW, [claude]).groups[0];
  assert.deepEqual([open.folded, open.summary.id], [false, "wk"], "an open group has its summary too");
  // failing: the summary comes from the last good reading, like the rows
  s.claude.report = errorReport("x", "offline", NOW);
  const f = cardModel(s, NOW, [claude], { ...DEFAULTS, folded: ["claude"] }).groups[0];
  assert.deepEqual([f.failed, f.dim, f.summary.percent], [true, true, "91%"]);
  assert.equal(cardModel({ claude: { ...s.claude, lastGood: null } }, NOW, [claude]).groups[0].summary, null);
});

test("card: hidden from the panel is absent; hidden from the bar is not", () => {
  const s = { claude: lim([win("5h", 30, NOW + 3600)]), codex: lim([win("wk", 10, NOW + 3600)]), opencode: spend(1200, 5000) };
  assert.deepEqual(cardModel(s, NOW, WITH_SPEND, { ...DEFAULTS, panelHidden: ["codex", "opencode"] }).groups.map((g) => g.providerId), ["claude"]);
  assert.deepEqual(cardModel(s, NOW, WITH_SPEND, { ...DEFAULTS, hidden: ["codex"], hiddenWindows: ["claude:5h"] }).groups.map((g) => [g.providerId, g.rows.length]), [
    ["claude", 1], ["codex", 1], ["opencode", 0],
  ]);
});

test("card: spend group has today/week strings and no rows; zero week is absent; failing keeps last good dimmed", () => {
  const g = cardModel({ opencode: spend(240000, 1_940_000, NOW - 60) }, NOW, [OC]).groups[0];
  assert.deepEqual([g.kind, g.name, g.today, g.week, g.rows, g.folded, g.summary, g.failed, g.dim, g.status], ["spend", "OpenCode", "240k", "1.9M", [], false, null, false, false, "updated just now"]);
  assert.equal(cardModel({ opencode: spend(0, 0) }, NOW, [OC]).empty, true);
  assert.equal(cardModel({ opencode: spend(0, 12) }, NOW, [OC]).groups[0].today, "0");
  // stale
  assert.equal(cardModel({ opencode: spend(5, 12, NOW - 901) }, NOW, [OC]).groups[0].dim, true);
  // failing with a last good reading: its numbers, dimmed, with the reason
  const failing = { ...spend(800, 9000, NOW - 1200), report: errorReport("y", "database is locked", NOW) };
  const f = cardModel({ opencode: failing }, NOW, [OC]).groups[0];
  assert.deepEqual([f.status, f.failed, f.dim, f.age, f.today, f.week], ["database is locked", true, true, "Last reading 20 min ago", "800", "9k"]);
  // failing with nothing known: the reason, no numbers
  const n = cardModel({ opencode: { report: errorReport("y", "timed out", NOW), lastGood: null, installed: true } }, NOW, [OC]).groups[0];
  assert.deepEqual([n.status, n.failed, n.today, n.week], ["timed out", true, null, null]);
  // not installed
  assert.equal(cardModel({ opencode: GONE }, NOW, [OC]).empty, true);
});

test("card: arrows only from three groups", () => {
  const two = { claude: lim([win("5h", 30, NOW + 3600)]), codex: lim([win("wk", 10, NOW + 3600)]) };
  assert.equal(cardModel(two, NOW, WITH_SPEND).arrows, false);
  assert.equal(cardModel({ ...two, opencode: spend(1, 2) }, NOW, WITH_SPEND).arrows, true);
  assert.equal(cardModel({ ...two, opencode: spend(0, 0) }, NOW, WITH_SPEND).arrows, false, "an absent group does not count");
  assert.equal(cardModel({ ...two, opencode: spend(1, 2) }, NOW, WITH_SPEND, { ...DEFAULTS, panelHidden: ["codex"] }).arrows, false);
});

const spendOn = (s, prefs = DEFAULTS) => barModel(s, prefs, NOW, WITH_SPEND).groups.filter((g) => g.providerId === "opencode");

test("bar: spend is off by default next to limits, on when no limits provider has windows", () => {
  const withLimits = { claude: lim([win("5h", 30, NOW + 3600)]), codex: GONE, opencode: spend(240000, 1_000_000) };
  assert.deepEqual(spendOn(withLimits), []);
  assert.equal(hasLimits(withLimits, WITH_SPEND), true);
  const alone = { claude: GONE, codex: GONE, opencode: spend(240000, 1_000_000) };
  assert.equal(hasLimits(alone, WITH_SPEND), false);
  assert.deepEqual(spendOn(alone), [{ providerId: "opencode", name: "OpenCode", icon: "i", mark: null, dim: false, segments: [], spend: "240k" }]);
  assert.deepEqual(spendOn({ ...alone, opencode: spend(0, 0) }), [], "zero week is not on the bar");
  assert.deepEqual(spendOn({ ...alone, opencode: GONE }), [], "not installed");
  assert.deepEqual(spendOn({ ...alone, opencode: NONE }), [], "no reading yet");
  const failing = { ...alone, opencode: { ...spend(500, 900, NOW - 1200), report: errorReport("y", "x", NOW) } };
  assert.deepEqual(spendOn(failing).map((g) => [g.mark, g.dim, g.spend]), [["!", true, "500"]]);
  const stale = { ...alone, opencode: spend(500, 900, NOW - 901) };
  assert.deepEqual(spendOn(stale).map((g) => [g.mark, g.dim]), [[null, true]]);
});

test("bar: Claude installed but with no windows (unavailable) does not count as limits", () => {
  const s = {
    claude: { report: unavailableReport("claude CLI", "No subscription limits", NOW), lastGood: null, installed: true },
    codex: { report: errorReport("codex", "Not signed in", NOW), lastGood: null, installed: true },
    opencode: spend(1500, 9000),
  };
  assert.equal(hasLimits(s, WITH_SPEND), false);
  assert.equal(limitsSettled(s, DEFAULTS, WITH_SPEND), true);
  assert.deepEqual(spendOn(s).map((g) => g.spend), ["2k"]);
  const empty = { ...s, claude: lim([]) };
  assert.equal(hasLimits(empty, WITH_SPEND), false, "an ok reading with no windows does not count");
});

test("bar: Claude offline after a good reading still counts as limits", () => {
  const s = { claude: lim([win("5h", 30, NOW + 3600)], NOW - 3600), codex: GONE, opencode: spend(1500, 9000) };
  s.claude.report = errorReport("claude CLI", "offline", NOW);
  assert.equal(hasLimits(s, WITH_SPEND), true);
  assert.deepEqual(spendOn(s), []);
  // a reading kept from before the CLI went away does not count
  const gone = { ...s, claude: { ...s.claude, report: null, installed: false } };
  assert.equal(hasLimits(gone, WITH_SPEND), false);
  assert.equal(spendOn(gone).length, 1);
});

test("bar: spend stays off until every wanted limits provider has answered once", () => {
  const s = { claude: NONE, codex: GONE, opencode: spend(1500, 9000) };
  assert.equal(limitsSettled(s, DEFAULTS, WITH_SPEND), false);
  assert.deepEqual(spendOn(s), []);
  // Claude answers with nothing to show: now spend goes on the bar
  s.claude = { report: unavailableReport("claude CLI", "No subscription limits", NOW), lastGood: null, installed: true };
  assert.equal(limitsSettled(s, DEFAULTS, WITH_SPEND), true);
  assert.equal(spendOn(s).length, 1);
  // a limits provider in neither bar nor panel is not fetched and is not waited for
  const unwanted = { claude: NONE, codex: GONE, opencode: spend(1500, 9000) };
  const prefs = { ...DEFAULTS, hidden: ["claude"], panelHidden: ["claude"] };
  assert.equal(limitsSettled(unwanted, prefs, WITH_SPEND), true);
  assert.equal(spendOn(unwanted, prefs).length, 1);
  // but one with a known reading still counts as limits
  const known = { ...unwanted, claude: { ...lim([win("5h", 30, NOW + 3600)]), report: null } };
  assert.equal(hasLimits(known, WITH_SPEND), true);
  assert.deepEqual(spendOn(known, prefs), []);
});

test("bar: an explicit spend choice wins both ways", () => {
  const withLimits = { claude: lim([win("5h", 30, NOW + 3600)]), codex: GONE, opencode: spend(1500, 9000) };
  assert.equal(spendOn(withLimits, { ...DEFAULTS, spendOnBar: { opencode: true } }).length, 1);
  const alone = { claude: GONE, codex: GONE, opencode: spend(1500, 9000) };
  assert.deepEqual(spendOn(alone, { ...DEFAULTS, spendOnBar: { opencode: false } }), []);
  const unsettled = { claude: NONE, codex: GONE, opencode: spend(1500, 9000) };
  assert.equal(spendOn(unsettled, { ...DEFAULTS, spendOnBar: { opencode: true } }).length, 1, "an explicit on does not wait");
  // the legacy bar list does not apply to spend
  assert.equal(spendOn(alone, { ...DEFAULTS, hidden: ["opencode"] }).length, 1);
});

test("wanted: on the bar or in the panel; in neither → false; spend follows its effective bar state", () => {
  const s = { claude: lim([win("5h", 30, NOW + 3600)]), codex: GONE, opencode: spend(1500, 9000) };
  assert.equal(wanted(DEFAULTS, claude, s, WITH_SPEND), true);
  assert.equal(wanted({ ...DEFAULTS, hidden: ["claude"] }, claude, s, WITH_SPEND), true, "panel only");
  assert.equal(wanted({ ...DEFAULTS, panelHidden: ["claude"] }, claude, s, WITH_SPEND), true, "bar only");
  assert.equal(wanted({ ...DEFAULTS, hidden: ["claude"], panelHidden: ["claude"] }, claude, s, WITH_SPEND), false);
  assert.equal(wanted(DEFAULTS, OC, s, WITH_SPEND), true, "panel by default");
  const noPanel = { ...DEFAULTS, panelHidden: ["opencode"] };
  assert.equal(wanted(noPanel, OC, s, WITH_SPEND), false, "off the bar next to limits, out of the panel");
  assert.equal(wanted(noPanel, OC, { ...s, claude: GONE }, WITH_SPEND), true, "on the bar by default with no limits");
  assert.equal(wanted({ ...noPanel, spendOnBar: { opencode: true } }, OC, s, WITH_SPEND), true);
  assert.equal(wanted({ ...noPanel, spendOnBar: { opencode: false } }, OC, { ...s, claude: GONE }, WITH_SPEND), false);
});

test("density: a spend group takes room", () => {
  const limitsOnly = barModel({ claude: lim([win("5h", 30, NOW + 3600)]) }, DEFAULTS, NOW, [claude]);
  const both = barModel({ claude: lim([win("5h", 30, NOW + 3600)]), opencode: spend(240000, 1_000_000) }, { ...DEFAULTS, spendOnBar: { opencode: true } }, NOW, [claude, OC]);
  assert.equal(both.groups.length, 2);
  // limits alone fit with bars at 120px; with the spend group they no longer do
  assert.equal(chooseDensity(limitsOnly, 120), 0);
  assert.ok(chooseDensity(both, 120) > 0);
  assert.equal(chooseDensity(both, 400), 0);
  const spendAlone = barModel({ opencode: spend(240000, 1_000_000) }, { ...DEFAULTS, spendOnBar: { opencode: true } }, NOW, [OC]);
  assert.equal(chooseDensity(spendAlone, 60), 3, "nothing to drop: it stays at the narrowest");
  assert.equal(chooseDensity(spendAlone, 200), 0);
});

// ---- the first rule, guarded further ----
import { extraScenarios, BAR_PREFS, DENSITY_WIDTHS } from "./_view-scenarios.js";
import { effectivePrefs as livePrefs } from "../lib/prefs.js";

test("card: a Claude + Codex panel shows no arrow, whichever providers are listed", () => {
  for (const [name, mk] of Object.entries({ ...scenarios, ...extraScenarios })) {
    for (const providers of [[claude, codex], WITH_SPEND, PROVIDERS]) {
      assert.equal(cardModel(mk(), SNAP_NOW, providers).arrows, false, `${name}, ${providers.length} providers`);
    }
  }
});

test("card and bar: OpenCode and Pi not installed (the state after their first fetch) change nothing", () => {
  const before = JSON.parse(readFileSync(join(HERE, "fixtures", "view-before.json"), "utf8"));
  for (const [name, mk] of Object.entries(scenarios)) {
    const st = { ...mk(), opencode: GONE, pi: GONE };
    const card = cardModel(st, SNAP_NOW, PROVIDERS);
    assert.equal(card.arrows, false, name);
    assert.deepEqual(strip(card), before[name].card, `${name} card`);
    assert.deepEqual(barModel(st, DEFAULTS, SNAP_NOW, PROVIDERS), before[name].bar, `${name} bar`);
    assert.deepEqual(barModel(st, livePrefs(undefined, undefined), SNAP_NOW, PROVIDERS), before[name].bar, `${name} bar, live default prefs`);
  }
});

test("card, bar and density: a passed reset, tight windows and bar prefs give what 19fda91 gave", () => {
  const before = JSON.parse(readFileSync(join(HERE, "fixtures", "view-before-extra.json"), "utf8"));
  for (const [name, mk] of Object.entries(extraScenarios)) {
    for (const [pname, raw] of Object.entries(BAR_PREFS)) {
      const want = before[name][pname];
      const prefs = livePrefs(raw, undefined);
      for (const extra of [{}, { opencode: GONE, pi: GONE }]) {
        for (const providers of [[claude, codex], PROVIDERS]) {
          const at = `${name}, ${pname}, ${providers.length} providers${extra.pi ? ", spend not installed" : ""}`;
          const st = { ...mk(), ...extra };
          const card = cardModel(st, SNAP_NOW, providers, prefs);
          assert.equal(card.arrows, false, at);
          assert.deepEqual(strip(card), want.card, `${at}: card`);
          const bar = barModel(st, prefs, SNAP_NOW, providers);
          assert.deepEqual(bar, want.bar, `${at}: bar`);
          const density = Object.fromEntries(DENSITY_WIDTHS.map((w) => [w, chooseDensity(bar, w, prefs.showBars)]));
          assert.deepEqual(density, want.density, `${at}: density`);
        }
      }
    }
  }
});
