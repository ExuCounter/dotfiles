---
name: drop-worktree
description: "Remove a git worktree and its herdr workspace together. Use when the user asks to drop, delete, close, remove, or clean up a worktree. Requires HERDR_ENV=1."
---

# drop-worktree

Tear down a git worktree AND its herdr workspace in one shot. Neither half is enough on its own — the git worktree can leave a stale herdr workspace, and closing the workspace leaves the git worktree on disk.

## Preconditions

```bash
test "${HERDR_ENV:-}" = 1
command -v herdr
command -v git
```

If any check fails, say what's missing and stop.

## Identify the target

Ask the user which worktree to drop unless they've named one. Show the current list to help them choose:

```bash
herdr worktree list | jq '.result.worktrees[] | select(.is_linked_worktree) | {branch, path, workspace_id: .open_workspace_id}'
```

Never guess the target. If more than one worktree matches an ambiguous name, ask which.

## Safety check

Before removing, look for uncommitted work:

```bash
git -C <worktree-path> status --porcelain
```

If output is non-empty, tell the user what's dirty and ask for explicit confirmation ("yes, drop it anyway"). Do not silently discard work.

## Remove via herdr

`herdr worktree remove --workspace <id>` handles both halves atomically — deletes the git worktree AND closes the herdr workspace:

```bash
herdr worktree remove --workspace <workspace-id>
```

If the worktree is dirty and the user confirmed, add `--force`.

## Verify

Confirm both halves are gone:

```bash
git worktree list                                  # target path should be gone
herdr workspace list | jq '.result.workspaces[] | select(.workspace_id == "<id>")'  # empty
```

If either still shows the removed target, fall back:
- Stale git worktree: `git worktree remove <path> --force`
- Stale herdr workspace: `herdr workspace close <workspace-id>`

## Delete the branch

Removing a worktree does not delete the branch. **Delete the branch by default** — most worktree branches are created fresh by `/spawn-worktree` and are throwaway once the worktree goes.

Safety check first: is there work on this branch that isn't on any remote?

```bash
# Unpushed commits (branch commits not in any remote tracking ref)
git log --oneline <branch-name> --not --remotes
```

If that returns any commits, warn the user and ask before deleting. Otherwise delete without asking:

```bash
git branch -D <branch-name>
```

Skip the deletion only if the user explicitly says "keep the branch".

## Report back

One line: what was removed, whether the branch was kept.
