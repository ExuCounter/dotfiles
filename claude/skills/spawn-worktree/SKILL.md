---
name: spawn-worktree
description: "Spawn a new git worktree under worktrees/<branch> as a herdr workspace and start a Claude session inside it, without switching the user's view. Use when the user asks to start a new task in a worktree, spawn a worktree, or fork off into a fresh workspace. Requires HERDR_ENV=1 and a git repo."
---

# spawn-worktree

Create a git worktree under `worktrees/<branch-name>` in the repo root, open it as a herdr workspace (without stealing focus), and start Claude inside it. The default is to do all three steps — do not skip the Claude start unless the user explicitly says so.

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

## Create the worktree

`/worktrees/` is excluded globally via `core.excludesFile` (dotfiles-managed), so it
never needs a per-repo `.gitignore` entry.

Do NOT pass `--base` by default. Many repos don't have `origin/HEAD` set, and hardcoding a base ref like `origin/HEAD` or `main` will fail with `invalid reference`. Let herdr resolve the default (current HEAD).

Only add `--base <ref>` if the user explicitly names a starting point (e.g., "branch from main", "branch from origin/develop"). Then first verify the ref exists:

```bash
git rev-parse --verify <ref>
```

Base command — `--path` is relative to the repo root, `--no-focus` keeps the user's
current view untouched. `--path worktrees/<branch-name>` is load-bearing beyond herdr:
Whiska derives a mouse's worktree root and main checkout from exactly this layout
(Whiska ADR-0030, `Whiska.Layout`). Do not change it without changing Whiska.

```bash
herdr worktree create \
  --workspace "$HERDR_WORKSPACE_ID" \
  --branch <branch-name> \
  --label <branch-name> \
  --path worktrees/<branch-name> \
  --no-focus
```

Capture the JSON response. You need:

- `.result.workspace.workspace_id` → the new workspace ID
- `.result.root_pane.pane_id` → the root pane in that workspace

If the response is missing either field, stop and report the raw response. Do not guess IDs.

## Carry Whiska's hooks into the worktree — before Claude starts

A worktree only contains committed files. When the repo's `.claude/` folder is not
committed (a work repo where `whiska init` was run but the folder was never added),
the new worktree has no `Stop` hook, so the session there never writes to the doorstep
and the owl never sees it finish or ask anything. Claude Code loads hooks at startup, so
this has to happen before `agent start`, not after.

If the main checkout has `.claude/hooks/whiska.sh` and the new worktree has no
`.claude/settings.json`, copy the setup over — the hooks, the skills and the settings,
never `settings.local.json` (it is this machine's local overrides):

```bash
if [ -f .claude/hooks/whiska.sh ] && [ ! -f worktrees/<branch-name>/.claude/settings.json ]; then
  mkdir -p worktrees/<branch-name>/.claude
  cp -R .claude/hooks .claude/settings.json worktrees/<branch-name>/.claude/
  [ -d .claude/skills ] && cp -R .claude/skills worktrees/<branch-name>/.claude/
fi
```

Skip it silently when the worktree already has a `settings.json` (the folder is
committed there, which is the ADR-0016 shape) or when the main checkout has no Whiska.
The copy is untracked in the worktree and disappears with it.

## Start Claude in the new workspace

This is the default. Only skip if the user said "don't start Claude" or equivalent.

`agent start` polls for shell readiness internally — don't sleep first, just call it
with a generous timeout:

```bash
herdr agent start <branch-name> --kind claude --pane <root-pane-id> --timeout 15000
```

## Hand off the task

If this worktree was spawned because of a specific task (a feature, a fix — not a bare
"spawn me a worktree" with nothing to do yet), send that task to the new session so it
starts working without the user retyping anything:

```bash
herdr agent prompt <root-pane-id> "<the task, in the user's own words>"
```

Write the task text the way the user described it — don't summarize it into something
thinner. If there was no specific task (the user just wanted an empty worktree), skip
this step.

## Checking on it

Questions from this worktree reach you through Whiska when this repo has been
`whiska init`-ed and the owl is running (`whiska doctor` checks). Every turn there ends
with a worktree-status marker; Whiska delivers a one-line pointer into the main session
and `whiska questions <id>` shows the whole message. Do not read the pane to find out
what it said: Claude Code runs on the alternate screen and `herdr pane read` returns a
truncated tail.

## Report back

One line: "Created worktree <branch> at worktrees/<branch>, Claude is working on it
there." Say that it won't interrupt them and that Whiska will deliver its question when
it has one. Do not linger. Do not do any of the task yourself, in this session — that's
what the new one is for.
