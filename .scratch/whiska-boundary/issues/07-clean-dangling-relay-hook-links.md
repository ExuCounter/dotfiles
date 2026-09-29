# 07 — Remove the dangling relay hook symlinks and make dotbot clean that directory

Status: done
Repo: dotfiles
Blocked by: none.

`~/.claude/hooks/herdr-worktree-notify.sh` and `~/.claude/hooks/herdr-worktree-resume.sh`
are dangling symlinks left by the relay removal (commit eec3ef0). dotbot's `clean:
["~"]` only prunes `~` itself.

Do: add `~/.claude/hooks` (and `~/.claude/skills`) to the `clean:` list in
`install.conf.yaml` so `./install` removes dead links there. Run `./install` once.

## Test

`for f in ~/.claude/hooks/* ~/.claude/skills/*; do [ -e "$f" ] || echo "$f"; done`
prints nothing.

## Comments

2026-09-28: Done on feat/whiska-boundary: `clean:` now lists ~/.claude/hooks and ~/.claude/skills. The two dead links disappear on the next ./install from the main checkout after merge (not run from the worktree, since that would repoint every link at the worktree).
