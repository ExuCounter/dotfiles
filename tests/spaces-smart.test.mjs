import { test } from "node:test";
import assert from "node:assert/strict";
import { arrange, fold } from "../herdr-app/mods/spaces-smart/smart.mjs";

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
