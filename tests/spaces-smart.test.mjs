import { test } from "node:test";
import assert from "node:assert/strict";
import { arrange, fold, line, wentStale } from "../herdr-app/mods/spaces-smart/smart.mjs";

// A space as the mod's ordered() sees it: the space, its index, its git.
const space = (id, g = null, w = {}) => ({ w: { id, name: id, machine: null, active: false, ...w }, i: 0, g });
const repo = (name, on = null) => JSON.stringify([on, `/r/${name}/.git`]);
const main = (name, on) => ({ name, repo: repo(name, on), linked: false });
const worktree = (name, on) => ({ name, repo: repo(name, on), linked: true });

// The sidebar as text: "▾ name" a heading, "▾ [name]" a main checkout heading
// its group, "├─ name" a worktree beneath, "name" a plain row.
const view = (entries) => entries.map((e) => {
  const chevron = e.folded ? "▸" : "▾";
  if (e.heading) return `${chevron} ${e.heading.name}`;
  if (e.lead) return `${chevron} [${e.w.name}]`;
  return e.tree ? `${e.tree} ${e.w.name}` : e.w.name;
});
const sidebar = (list, folded = new Set()) => view(fold(arrange(list), folded));

test("worktrees whose main checkout is not open go under a heading named for the repo", () => {
  const list = [space("platform"), space("feat/a", worktree("dotfiles")), space("feat/b", worktree("dotfiles"))];
  assert.deepEqual(sidebar(list), ["platform", "▾ dotfiles", "├─ feat/a", "└─ feat/b"]);
});

test("an open main checkout leads its group, its worktrees moved beneath it", () => {
  const list = [space("feat/a", worktree("dotfiles")), space("platform"), space("dotfiles", main("dotfiles"))];
  assert.deepEqual(sidebar(list), ["▾ [dotfiles]", "└─ feat/a", "platform"]);
  assert.deepEqual(arrange(list).map((r) => r.w.id), ["dotfiles", "feat/a", "platform"]);
});

test("a main checkout with no worktree open stays a plain row", () => {
  const list = [space("dotfiles", main("dotfiles")), space("platform")];
  assert.deepEqual(sidebar(list), ["dotfiles", "platform"]);
});

test("each repo is one group at its first space's place, whatever the core's order", () => {
  const list = [space("a1", worktree("alpha")), space("b1", worktree("beta")), space("a2", worktree("alpha"))];
  assert.deepEqual(sidebar(list), ["▾ alpha", "├─ a1", "└─ a2", "▾ beta", "└─ b1"]);
  assert.deepEqual(arrange(list).map((r) => r.w.id), ["a1", "a2", "b1"]);
});

test("the same repo on two machines is two groups", () => {
  const list = [space("here", worktree("dotfiles")), space("there", worktree("dotfiles", "vps"), { machine: "vps" })];
  assert.deepEqual(sidebar(list), ["▾ dotfiles", "└─ here", "▾ dotfiles", "└─ there"]);
});

test("a folded group shows its heading alone, but keeps the shown space in view", () => {
  const list = [space("feat/a", worktree("dotfiles")), space("feat/b", worktree("dotfiles"), { active: true }), space("feat/c", worktree("dotfiles"))];
  const folded = new Set([repo("dotfiles")]);
  assert.deepEqual(sidebar(list, folded), ["▸ dotfiles", "└─ feat/b"]);
});

test("a folded group led by its main checkout keeps the main checkout's row", () => {
  const list = [space("dotfiles", main("dotfiles")), space("feat/a", worktree("dotfiles"))];
  assert.deepEqual(sidebar(list, new Set([repo("dotfiles")])), ["▸ [dotfiles]"]);
});

// A terminal as terminals() gives it: its labels and the agent's report.
const terminal = (labels, report = null) => ({ address: "t1", labels, report });
const mouse = (space, labels = {}, report = null) =>
  terminal({ "herdr.space": space, "whiska.branch": "feat/a", ...labels }, report);
const NOW = 1_800_000_000_000;

test("a worktree's line is its mouse's last report, first line only", () => {
  const sp = { id: "sp1", machine: null };
  const terms = [terminal({ "herdr.space": "sp1" }), mouse("sp1", {}, { state: "done", msg: "Tests pass.\nAll 7 of them." })];
  assert.deepEqual(line(sp, terms, NOW), { msg: "Tests pass.", ask: false, labels: [], stale: false });
  assert.equal(line({ id: "sp2", machine: null }, terms, NOW), null);
});

test("a question in the report marks the line as asking", () => {
  const terms = [mouse("sp1", {}, { state: "blocked", msg: "❓ which path, A or B?" })];
  assert.equal(line({ id: "sp1", machine: null }, terms, NOW).ask, true);
});

test("the owl's labels follow, merge request, CI then review, toned as Whiska's sidebar rows were", () => {
  const labels = { "whiska.review": "needs rebase", "whiska.mr": "!7", "whiska.ci": "CI failed", "whiska.at": String(NOW) };
  assert.deepEqual(line({ id: "sp1", machine: null }, [mouse("sp1", labels)], NOW).labels, [
    { text: "!7", tone: null },
    { text: "CI failed", tone: "red" },
    { text: "needs rebase", tone: "yellow" },
  ]);
});

test("every owl word has the tone lib/whiska/herdr_config.ex gave it", () => {
  const tones = {
    "CI passed": "green", "CI failed": "red", "CI running": "blue", "CI stuck": "red",
    ready: "green", merged: "green", "merged · uncommitted": "yellow",
    "auto-merge": "blue", merging: "blue", rebasing: "blue", "rebase after CI": "blue",
    "needs approval": "yellow", "needs rebase": "yellow", "2 open threads": "yellow",
    "rebase refused": "red", conflict: "red", blocked: "red", closed: "red",
    draft: "dim", unread: "dim", "something new": null,
  };
  for (const [word, tone] of Object.entries(tones)) {
    const [label] = line({ id: "sp1", machine: null }, [mouse("sp1", { "whiska.review": word })], NOW).labels;
    assert.equal(label.tone, tone, word);
  }
});

test("the owl's labels go stale once whiska.at is over three minutes old", () => {
  const at = (ms) => line({ id: "sp1", machine: null }, [mouse("sp1", { "whiska.ci": "CI passed", ...ms })], NOW).stale;
  assert.equal(at({ "whiska.at": String(NOW - 180_001) }), true);
  assert.equal(at({ "whiska.at": String(NOW - 179_000) }), false);
  assert.equal(at({}), false);
});

test("a mouse with no report and no labels has no line", () => {
  assert.equal(line({ id: "sp1", machine: null }, [mouse("sp1", {}, { state: "idle" })], NOW), null);
});

test("a space on another machine finds its mouse by the label that machine wrote", () => {
  const terms = [{ ...mouse("sp1", {}, { msg: "on it" }), address: "vps/t4" }];
  assert.equal(line({ id: "vps/sp1", machine: "vps" }, terms, NOW).msg, "on it");
});

test("a timer learns when a mouse's labels went stale since its last look", () => {
  const terms = (at) => [terminal({ "herdr.space": "sp1" }), mouse("sp1", { "whiska.at": String(at) })];
  assert.equal(wentStale(terms(NOW - 180_000 - 5_000), NOW, 15_000), true);
  assert.equal(wentStale(terms(NOW - 180_000 - 20_000), NOW, 15_000), false);
  assert.equal(wentStale(terms(NOW - 60_000), NOW, 15_000), false);
});
