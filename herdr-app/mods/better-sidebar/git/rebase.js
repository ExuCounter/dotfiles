// Rebasing a merge request's branch on its target from the card: tried first in a throwaway
// worktree, so the branch is only touched when the rebase goes through without conflicts.
import { exec } from "herdr";

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

export const resolvePrompt = (target, files) =>
  [
    `Rebase this branch on origin/${target} (git fetch origin ${target} first) and resolve the conflicts`,
    files.length ? ` in ${files.join(", ")}` : "",
    ", keeping what both sides meant. Run the tests the conflicting files touch,",
    " then show me the result; don't push until I say so.",
  ].join("");
