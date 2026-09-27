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
current view untouched:

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

One line: "Created worktree <branch> at worktrees/<branch>, Claude is working on it
there." Do **not** promise to let them know when it needs something — nothing delivers
that any more. Say instead that it won't interrupt them, and offer to check on it. Do not
linger. Do not do any of the task yourself, in this session — that's what the new one is
for.
