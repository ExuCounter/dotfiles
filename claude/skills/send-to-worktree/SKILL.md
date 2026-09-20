---
name: send-to-worktree
description: "Route a follow-up idea into an already-running worktree's Claude session instead of spawning a new worktree, without blocking or switching the user's view. Use when the user has an active worktree/feature in progress and gives a new idea, refinement, or sub-task that belongs to that same branch rather than a separate one."
---

# send-to-worktree

Send a message into a worktree session that's already running, instead of creating a
new one. Use this when the new idea is a continuation of work already in flight on some
branch — not a separate, independently-shippable unit of work (that's `spawn-worktree`
instead; see the decision rule below).

## Preconditions

```bash
test "${HERDR_ENV:-}" = 1
command -v herdr
command -v jq
```

If any check fails, say what's missing and stop.

## Decide: route here, or spawn new?

git cannot have two worktrees on the same branch at once, so the real question is
whether this idea belongs on a branch that already has a worktree:

- **Same branch/PR-sized unit of work** (a refinement, sub-part, or follow-up on the
  feature already being built there) → route it here.
- **A separate concern** (unrelated bug, a second feature that could ship on its own,
  something that would conflict if done in parallel with what's running) → use
  `spawn-worktree` instead, not this skill.

If it's not obvious from the idea itself which case applies, ask the user one direct
question naming the candidate worktree/branch — don't guess silently either way.

## Find the target worktree

List active worktrees and match by branch name or description of what's being built:

```bash
herdr worktree list | jq '.result.worktrees[] | select(.is_linked_worktree) | {branch, path, workspace_id: .open_workspace_id}'
```

If more than one plausibly matches, ask which. If none match, this isn't a routing
case — say so and suggest `spawn-worktree` instead.

## Get the pane and check its status

```bash
herdr pane list --workspace <workspace-id> | jq '.result.panes[0] | {pane_id, agent_status}'
```

`agent_status` tells you what you're sending into:

- `working` — the session is mid-task. Sending now is fine (it queues), but say so in
  your report back — don't imply it'll be picked up instantly.
- `idle` or `blocked` — sending now will likely be seen right away.

## Send it — do not wait

```bash
herdr agent prompt <pane-id> "<the idea, in the user's own words>"
```

Do **not** pass `--wait`. This must return immediately — the entire point is that the
user's current terminal never blocks on the routed session's work.

Write the idea the way the user phrased it; don't compress it into a shorter summary
that drops detail the other session will need.

## Nothing else to do — the hook handles the reply

The routed session may hit a decision point that needs the user before it can act on
this, or it may just finish. **You don't need to launch or relaunch anything** — a
global `Stop` hook (`herdr-worktree-notify.sh`, dotfiles-managed) fires on every
completed turn in every session and checks for the `[worktree-status: ...]` marker
automatically, as long as the worktree already has a `.herdr-worktree-meta` file at its
root (written once by `spawn-worktree` when it was created).

This matters specifically because of how the previous design broke: it required
relaunching a one-shot watcher after *every single reply*, and a coordinating session
that sent the reply but forgot that step silently killed all future notifications for
that worktree — with nothing to indicate anything was wrong. A hook can't be forgotten;
it just runs. If you want to check whether anything is stuck undelivered right now,
`herdr-worktree-wake.sh status` reports it instantly.

## What arrives in your terminal, and how to answer it

When that worktree session ends a turn with a `[worktree-status: ...]` marker, a single
line is delivered into your pane, shaped like this:

```
[auto] worktree fix/foo (pane w1B:p1): [worktree-status: needs-decision] 3 questions ready, see above | full message: /Users/you/.herdr/worktree-relay/fix-foo/1758…-needs-decision.md — read that file for the complete content; the worktree pane's scrollback cannot be read back (Claude runs on the terminal's alternate screen) | reply with: herdr agent prompt w1B:p1 "<your answer>"
```

Three parts, and all three matter:

1. **The marker**, inline — enough to tell what kind of interruption this is without
   reading anything.
2. **A relay file path** holding that turn's *complete* response text. `cat` it. This is
   the whole content, questions and all — you never need to fetch anything from the
   worktree pane or ask that session to repeat itself.
3. **A ready-to-run reply command**, pane id already filled in.

Do **not** try `herdr pane read <pane>` to recover the worktree's output. It will return
a truncated tail no matter what `--lines` you pass: Claude Code runs on the terminal's
alternate screen, and herdr's own docs state that rows leaving the alternate screen never
enter host scrollback. That is exactly why the content is pushed to a file instead.

Then: relay the questions to the user **one at a time** (`AskUserQuestion`), per the
global CLAUDE.md rule, and send each answer back with the command from part 3.

## Report back

One line: which worktree/branch the idea went to, whether that session was `working`
(queued) or free to pick it up immediately, and that you'll flag it here if it needs
anything. Do not linger, do not start investigating the idea yourself here.
