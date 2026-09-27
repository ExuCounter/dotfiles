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

## Checking on it — nothing will interrupt you

The new session may hit a decision point that needs the user — a `grilling` question,
anything it can't resolve alone — or it may just finish. **Nothing will tell you when
that happens.** The bash relay that used to push a notification into your pane has been
removed, and Whiska's owl has not yet grown the half that delivers a collected question
to the main session.

So the worktree writes, and you go and look. Every turn there ends with a
`[worktree-status: ...]` marker (the global "Worktree status marker" rule), and its whole
final message — questions, options, recommendations — is written to that repo's doorstep
by Whiska's `Stop` hook, whether or not the owl is running:

```bash
ls <main-checkout>/.git/whiska/doorstep/*.json     # still waiting
```

A `.collected` suffix means the owl has already filed it as a question in that repo's
house. Neither state pings you.

Practically, that means: when you have handed work to a worktree and have nothing else to
do, check on it rather than assuming silence is progress. `herdr agent prompt <pane-id>
"<your answer>"` is still how you reply — `herdr worktree list` and the pane id from the
create response are how you find it.

Do **not** try `herdr pane read <pane>` to recover what the session said. It returns a
truncated tail no matter what `--lines` you pass: Claude Code runs on the terminal's
alternate screen, and rows that leave it never enter host scrollback. The doorstep entry
is the full text; the pane is not.

## Report back

One line: which worktree/branch the idea went to, and whether that session was `working`
(queued) or free to pick it up immediately. Say plainly that nothing will interrupt the
user when it needs something — offer to check on it instead. Do not linger, do not start
investigating the idea yourself here.
