// Provider states for the "nothing changes for a Claude + Codex user" guard in view.test.js.
// test/fixtures/view-before.json is cardModel/barModel of these, from the code before spend.
import claude from "../providers/claude.js";
import codex from "../providers/codex.js";
import { read } from "./_util.js";

export const NOW = Date.UTC(2026, 10, 4, 8, 0, 0) / 1000;
const ok = (p, file, at = NOW) => ({ ...p.parse(read(file), at), observedAt: at });
const fresh = () => ({
  claude: { report: ok(claude, "claude-get-usage.max.json"), lastGood: ok(claude, "claude-get-usage.max.json"), installed: true },
  codex: { report: ok(codex, "codex-app-server.plus.json"), lastGood: ok(codex, "codex-app-server.plus.json"), installed: true },
});
const error = (message) => ({ status: "error", message, plan: null, observedAt: NOW, source: "x", windows: [] });

export const scenarios = {
  fresh,
  failingWithLastGood: () => {
    const s = fresh();
    s.claude.lastGood = { ...s.claude.lastGood, observedAt: NOW - 1200 };
    s.claude.report = error("Not logged in");
    return s;
  },
  failingNoLastGood: () => ({ ...fresh(), codex: { report: error("offline"), lastGood: null, installed: true } }),
  stale: () => {
    const s = fresh();
    s.codex.report = { ...s.codex.report, observedAt: NOW - 901 };
    return s;
  },
  loadingAndMissing: () => ({ claude: { report: null, lastGood: null, installed: null }, codex: { report: null, lastGood: null, installed: false } }),
  noState: () => ({}),
};

// More of the same guard: test/fixtures/view-before-extra.json is what the code at 19fda91
// gives for these (its lib/view.js, lib/prefs.js and providers, run once from a copy).
// Each state is drawn with each of BAR_PREFS, as main.js does: through effectivePrefs.
export const extraScenarios = {
  // Claude's 5-hour reset has passed (shown as —) and Codex's weekly one too.
  expired: () => {
    const s = fresh();
    const pass = (r, id) => ({ ...r, windows: r.windows.map((w) => (w.id === id ? { ...w, resetsAt: NOW - 60 } : w)) });
    s.claude = { ...s.claude, report: pass(s.claude.report, "session"), lastGood: pass(s.claude.lastGood, "session") };
    s.codex = { ...s.codex, report: pass(s.codex.report, "codex:secondary"), lastGood: pass(s.codex.lastGood, "codex:secondary") };
    return s;
  },
  // Hot and warm windows, so the times to reset and the density steps show.
  tight: () => {
    const s = fresh();
    const set = (r, id, percent) => ({ ...r, windows: r.windows.map((w) => (w.id === id ? { ...w, percent } : w)) });
    s.claude = { ...s.claude, report: set(set(s.claude.report, "session", 93), "weekly_all", 74) };
    s.codex = { ...s.codex, report: set(s.codex.report, "codex:primary", 81) };
    return s;
  },
  fresh,
};

export const BAR_PREFS = {
  defaults: undefined,
  hiddenProvider: { hidden: ["codex"], hiddenWindows: [], showResetTime: false },
  hiddenWindowsAndResetTime: { hidden: [], hiddenWindows: ["claude:weekly_scoped:Fable", "codex:codex:primary"], showResetTime: true },
  resetTimeNoBars: { hidden: [], hiddenWindows: ["claude:session"], showResetTime: true, showBars: false },
};

export const DENSITY_WIDTHS = [2000, 800, 600, 500, 400, 300, 250, 200, 160, 140, 120, 100, 60];
