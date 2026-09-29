---
name: send-to-worktree
description: "Route a follow-up idea into an already-running worktree's Claude session instead of spawning a new worktree, without blocking or switching the person's view. Use when there is an active worktree/feature in progress and the person gives a new idea, refinement, or sub-task belonging to that same branch rather than a separate one."
---

# send-to-worktree

Send a message into a mouse that is already running, instead of creating a new one. Use
this when the new idea continues work already in flight on some branch — not a separate,
independently-shippable unit of work, which is `spawn-worktree`'s job.

Installed by `whiska init` (Whiska ADR-0046).

## Preconditions

```bash
test "${HERDR_ENV:-}" = 1
command -v herdr
command -v jq
```

If any check fails, say what is missing and stop.

## Decide: route here, or spawn new?

git cannot have two worktrees on one branch at once, so the real question is whether
this idea belongs on a branch that already has one:

- **Same branch-and-PR-sized unit of work** — a refinement, sub-part or follow-up on the
  feature already being built there → route it here.
- **A separate concern** — an unrelated bug, a second feature that could ship on its
  own, something that would conflict if done in parallel → use `spawn-worktree`, not
  this skill.

If it is not obvious from the idea itself, ask the person one direct question naming the
candidate worktree and branch. Do not guess silently either way.

## Find the target worktree

List active worktrees and match by branch name, or by what is being built there:

```bash
herdr worktree list | jq '.result.worktrees[] | select(.is_linked_worktree) | {branch, path, workspace_id: .open_workspace_id}'
```

If more than one plausibly matches, ask which. If none match, this is not a routing case
— say so and suggest `spawn-worktree`.

## Get the pane and check its status

```bash
herdr pane list --workspace <workspace-id> | jq '.result.panes[0] | {pane_id, agent_status}'
```

`agent_status` tells you what you are sending into:

- `working` — mid-task. Sending now is fine (it queues), but say so when you report
  back; do not imply it will be picked up instantly.
- `idle` or `blocked` — it will likely be seen right away.

## Send it — do not wait

```bash
herdr agent prompt <pane-id> "<the idea, in the person's own words>"
```

Do **not** pass `--wait`. This must return immediately: the entire point is that the
person's own terminal never blocks on the routed mouse's work.

Write the idea the way the person phrased it. Do not compress it into a summary that
drops detail the mouse will need.

## Checking on it

Questions from this mouse reach the main session through Whiska, once this repo has been
`whiska init`-ed and the owl is running (`whiska doctor` checks both). Every turn there
ends with a worktree-status marker, Whiska delivers a one-line pointer, and
`whiska questions <id>` shows the whole message. Do not read the pane to find out what
it said: Claude Code runs on the alternate screen, so `herdr pane read` returns a
truncated tail.

## Report back

One line: which worktree and branch the idea went to, and whether that mouse was
`working` (queued) or free to pick it up now. Say that it will not interrupt the person
and that Whiska delivers its question when it has one. Do not linger, and do not start
investigating the idea yourself here.
