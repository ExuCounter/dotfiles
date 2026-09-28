# 08 — Claude Code's native worktrees do not fit Whiska's layout

Status: done-A
Repo: both
Blocked by: none.

`claude/settings.json` sets `worktree.baseRef: "fresh"` and `.gitignore` ignores
`.claude/worktrees/`, so Claude Code's own `EnterWorktree` creates
`<repo>/.claude/worktrees/<name>`. `Whiska.Layout` recognises only
`<main-checkout>/worktrees/<branch>` (ADR-0030). A session in a native worktree is
therefore neither a mouse nor the main checkout: its `Stop` hook is a no-op, containment
does not apply, and the statusline does not count it.

Options:

**A. Disable native worktrees in dotfiles (recommended).** Remove the `worktree` key
from `claude/settings.json` and the `.claude/worktrees/` ignore. `spawn-worktree` is the
one way to make a worktree, so every worktree is a mouse. Cheapest, matches ADR-0023
(one mouse per worktree, enforced).

**B. Teach Whiska a second layout.** `Layout.resolve` also accepts `.claude/worktrees/`.
Costs a Whiska ADR (0030 says "lean on exactly that layout") and a second convention to
keep in step.

**C. Leave it.** Accept that native worktrees are outside Whiska. Risk: a session there
edits the main checkout freely and asks questions nobody delivers, and the person cannot
tell from the statusline.

## Comments

2026-09-28: Applied option A on feat/whiska-boundary under the user's 'drop things that produce bad results' instruction: removed `worktree.baseRef` from claude/settings.json and `.claude/worktrees/` from .gitignore. Reversible in one commit if native worktrees are wanted back.
