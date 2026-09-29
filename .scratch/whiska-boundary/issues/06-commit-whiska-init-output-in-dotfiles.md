# 06 — Does dotfiles commit its own `whiska init` output?

Status: needs-decision
Repo: dotfiles
Blocked by: none.

The main checkout has untracked `.claude/settings.json`, `.claude/hooks/whiska.sh`,
`.claude/hooks/whiska-statusline.sh` and `.claude/skills/whiska-questions/`, written by
`whiska init`. ADR-0016 says commit them so the rules travel with the repo; ADR-0035 made
the committed files machine-independent for exactly this reason.

**Recommendation: commit them.** dotfiles is the repo whose worktrees are mice most often
(this one included). Without the commit, a worktree created from a clean clone has no
`Stop` hook and its questions are never written.

Against: the `.claude/settings.json` also carries the project statusline, which wraps the
global one; committing it means every clone of dotfiles gets Whiska's statusline whether
or not Whiska is installed. The shim fails open and the statusline script prints only the
global output when `whiska` is missing, so the cost is one failed lookup per statusline
refresh.

If yes: `git add .claude/` on the main checkout, commit as `chore: enable whiska`, same
wording Whiska used for its own repo.

## Comments
