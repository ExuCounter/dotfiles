---
name: drop-worktree
description: "Remove a git worktree and its herdr workspace together, once the work on it has landed. Use when the person asks to drop, delete, close, remove, or clean up a worktree. Requires HERDR_ENV=1."
---

# drop-worktree

Tear down a git worktree and its herdr workspace in one go. Neither half is enough on
its own: removing the git worktree leaves a stale herdr workspace, and closing the
workspace leaves the worktree on disk.

Installed by `whiska init` (Whiska ADR-0046). Dropping a worktree does not delete
anything of Whiska's: the mouse record survives the mouse, marked dead rather than
removed (Whiska ADR-0007), and its questions stay readable.

## Preconditions

```bash
test "${HERDR_ENV:-}" = 1
command -v herdr
command -v git
```

If any check fails, say what is missing and stop.

## Identify the target

Ask which worktree to drop unless the person named one. Show the list to help them
choose:

```bash
herdr worktree list | jq '.result.worktrees[] | select(.is_linked_worktree) | {branch, path, workspace_id: .open_workspace_id}'
```

Never guess the target. If more than one matches an ambiguous name, ask which.

## Safety check

Before removing, look for uncommitted work:

```bash
git -C <worktree-path> status --porcelain
```

If the output is non-empty, say what is dirty and ask for explicit confirmation ("yes,
drop it anyway"). Never silently discard work.

## Remove via herdr

`herdr worktree remove --workspace <id>` does both halves — deletes the git worktree and
closes the herdr workspace:

```bash
herdr worktree remove --workspace <workspace-id>
```

If the worktree is dirty and the person confirmed, add `--force`.

## Verify

Confirm both halves are gone:

```bash
git worktree list                                  # the target path should be gone
herdr workspace list | jq '.result.workspaces[] | select(.workspace_id == "<id>")'  # empty
```

If either still shows the target, fall back:

- Stale git worktree: `git worktree remove <path> --force`
- Stale herdr workspace: `herdr workspace close <workspace-id>`

## Delete the branch

Removing a worktree does not delete the branch. **Delete it by default** — most of these
branches were created fresh by `spawn-worktree` and are throwaway once the worktree
goes.

Safety check first: is there work on this branch that is on no remote?

```bash
git log --oneline <branch-name> --not --remotes
```

If that returns any commits, warn the person and ask before deleting. Otherwise delete
without asking:

```bash
git branch -D <branch-name>
```

Skip the deletion only if the person says to keep the branch.

## Report back

One line: what was removed, and whether the branch was kept.
