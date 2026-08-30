---
name: spawn-worktree
description: "Spawn a new git worktree as a herdr workspace, switch the user's view there, and start a Claude session inside it. Use when the user asks to start a new task in a worktree, spawn a worktree, or fork off into a fresh workspace. Requires HERDR_ENV=1 and a git repo."
---

# spawn-worktree

Create a git worktree, open it as a herdr workspace, focus the user's view there, and start Claude inside it. The default is to do all four steps — do not skip the focus or the Claude start unless the user explicitly says so.

## Preconditions

Before doing anything, verify:

```bash
test "${HERDR_ENV:-}" = 1
test -n "${HERDR_WORKSPACE_ID:-}"
git rev-parse --is-inside-work-tree
```

If any check fails, say what's missing and stop. Do not fall back to `git worktree add` — the point of this skill is the herdr integration.

## Ask for the branch name

Get the branch name from the user. Use `feat/<slug>`, `fix/<slug>`, or whatever convention the repo uses; check `git branch --show-current` and recent branches for hints. Do not invent a branch name silently.

## Create the worktree (always with --focus)

Do NOT pass `--base` by default. Many repos don't have `origin/HEAD` set, and hardcoding a base ref like `origin/HEAD` or `main` will fail with `invalid reference`. Let herdr resolve the default (current HEAD).

Only add `--base <ref>` if the user explicitly names a starting point (e.g., "branch from main", "branch from origin/develop"). Then first verify the ref exists:

```bash
git rev-parse --verify <ref>
```

Base command:

```bash
herdr worktree create \
  --workspace "$HERDR_WORKSPACE_ID" \
  --branch <branch-name> \
  --label <branch-name> \
  --focus
```

Capture the JSON response. You need:

- `.result.workspace.workspace_id` → the new workspace ID
- `.result.root_pane.pane_id` → the root pane in that workspace

If the response is missing either field, stop and report the raw response. Do not guess IDs.

## Belt-and-suspenders focus

`--focus` should already have moved the user's view. As a safety net, explicitly focus:

```bash
herdr workspace focus <new-workspace-id>
```

## Start Claude in the new workspace

This is the default. Only skip if the user said "don't start Claude" or equivalent.

The pane's shell takes ~2 seconds to initialise. Sleep first, then start Claude:

```bash
sleep 2
herdr agent start <branch-name> --kind claude --pane <root-pane-id>
```

If it still errors with "pane not at prompt", sleep 2 more seconds and retry once.

## Report back

One line: "Created worktree <branch>, switched you to it, Claude is starting." Do not linger. Do not offer to make edits — the user is now in a different session.
