# 03 — spawn-worktree and send-to-worktree: drop the doorstep walkthrough, record the layout contract

Status: done
Repo: dotfiles
Blocked by: none.

## What is wrong

Both skills carry a section "Checking on it — nothing will interrupt you" that:

- says nothing delivers (stale, see 02);
- teaches `ls <main-checkout>/.git/whiska/doorstep/*.json` and the `.collected` suffix,
  which are Whiska internals (ADR-0036) and can change under dotfiles;
- names `herdr agent prompt <pane> "<answer>"` as the reply path. ADR-0005 keys answers
  to a question id; the reply path is `whiska reply <id>`. A raw `herdr agent prompt`
  into a mouse is a new prompt, not an answer, and ADR-0037 will supersede the open
  question. Correct for `send-to-worktree`'s job, wrong as the way to answer.

## Change

In both skills, replace that section with:

> Questions from this worktree reach you through Whiska when this repo has been
> `whiska init`-ed and the owl is running (`whiska doctor` checks). Do not read the pane
> to find out what it said: Claude Code runs on the alternate screen and `herdr pane
> read` returns a truncated tail.

The "Report back" paragraphs lose "nothing delivers that any more" and say instead:
"it won't interrupt you; Whiska will deliver its question when it has one."

In `spawn-worktree` only, under "Create the worktree", add the contract line:

> `--path worktrees/<branch-name>` is load-bearing beyond herdr: Whiska derives a
> mouse's worktree root and main checkout from this exact layout (ADR-0030,
> `Whiska.Layout`). Do not change it without changing Whiska.

`send-to-worktree` keeps `herdr agent prompt` for routing and keeps the `agent_status`
check.

## Test

Read both skills end to end after the edit; grep the repo for `doorstep` and
`.collected` and expect no hits outside `.scratch/`.

## Comments

2026-09-28: Done on feat/whiska-boundary. Doorstep walkthrough replaced by the Whiska pointer in both skills; layout contract recorded in spawn-worktree; frontend-preview step 7 no longer spells the marker.
