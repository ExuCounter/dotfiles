// Rebasing a merge request's branch on its target from the card: tried first in a throwaway
// worktree, so the branch is only touched when the rebase goes through without conflicts.
import { exec, agents, hc } from "herdr";

async function git(folder, machine, args) {
  const result = await exec("git", args, { cwd: folder, on: machine ?? null });
  return { ok: result.code === 0, out: result.stdout.trim(), err: (result.stderr || result.stdout).trim() };
}

async function must(folder, machine, args) {
  const result = await git(folder, machine, args);
  if (!result.ok) throw new Error(result.err || `git ${args[0]} failed`);
  return result.out;
}

// { kind: "clean" } or { kind: "conflicts", files } for the checkout's branch on origin/<target>.
export async function tryRebase(folder, machine, target) {
  await must(folder, machine, ["fetch", "--quiet", "origin", target]);
  const trial = `${await must(folder, machine, ["rev-parse", "--path-format=absolute", "--git-common-dir"])}/better-sidebar-rebase`;
  await git(folder, machine, ["worktree", "remove", "--force", trial]);
  await must(folder, machine, ["worktree", "add", "--quiet", "--detach", trial, "HEAD"]);
  try {
    const rebase = await git(trial, machine, ["rebase", `origin/${target}`]);
    if (rebase.ok) return { kind: "clean" };
    const files = (await git(trial, machine, ["diff", "--name-only", "--diff-filter=U"])).out.split("\n").filter(Boolean);
    await git(trial, machine, ["rebase", "--abort"]);
    return { kind: "conflicts", files };
  } finally {
    await git(folder, machine, ["worktree", "remove", "--force", trial]);
  }
}

// The branch rebased in its own checkout, local edits kept aside meanwhile, then pushed so the
// merge request has it; the push refuses when someone else pushed in between.
export async function rebaseAndPush(folder, machine, target) {
  await must(folder, machine, ["rebase", "--autostash", `origin/${target}`]);
  await must(folder, machine, ["push", "--force-with-lease"]);
}

// The whole step, reported through `update({ state, text, files })`: "working", then "done",
// "conflicts" (with the files) or "error".
export async function rebaseFlow(folder, machine, target, update) {
  update({ state: "working", text: `Trying a rebase on ${target}…` });
  try {
    const trial = await tryRebase(folder, machine, target);
    if (trial.kind === "conflicts") {
      const names = trial.files.map((f) => f.split("/").pop());
      return update({ state: "conflicts", files: trial.files, text: `Conflicts in ${names.join(", ") || "some files"}` });
    }
    update({ state: "working", text: "Rebasing and pushing…" });
    await rebaseAndPush(folder, machine, target);
    update({ state: "done", text: `Rebased on ${target} and pushed` });
  } catch (e) {
    update({ state: "error", text: String(e?.message ?? e).split("\n")[0] });
  }
}

// The conflicts to the space's agent, which rebases and resolves them but leaves the push to me.
export async function resolveWithAgent(spaceId, target, files) {
  const agent = agents().find((a) => a.space === spaceId && a.address);
  if (!agent) return { state: "conflicts", files, text: "No agent in this space to send it to" };
  const result = await hc(["send", agent.address, resolvePrompt(target, files)]);
  return result.code === 0
    ? { state: "sent", files, text: `Sent to ${agent.tab_name || "the agent"}` }
    : { state: "conflicts", files, text: "Couldn't send: the agent is waiting on a dialog" };
}

export const resolvePrompt = (target, files) =>
  [
    `Rebase this branch on origin/${target} (git fetch origin ${target} first) and resolve the conflicts`,
    files.length ? ` in ${files.join(", ")}` : "",
    ", keeping what both sides meant. Run the tests the conflicting files touch,",
    " then show me the result; don't push until I say so.",
  ].join("");
