# 05 — Track the skill directories install.conf.yaml links to

Status: done
Repo: dotfiles
Blocked by: none.

`install.conf.yaml` links these into `~/.claude/skills/`, but they are untracked (`??`)
in the main checkout and absent from this worktree:

`c4-architecture`, `codebase-design`, `command-creator`, `domain-modeling`,
`domain-name-brainstormer`, `lesson-learned`, `wayfinder`, `writing-for-agents`.

A fresh `./install` creates dangling links. Whiska's `CLAUDE.md` requires
`domain-modeling` and `lesson-learned` after every feature and after every push
(`post-push-reflect.sh`), and its C4 rules assume `c4-architecture`. `skills-lock.json`
already pins the mattpocock ones by hash, so tracking them is consistent with how `tdd`,
`grilling` and `to-spec` are already handled.

Do: `git add claude/skills/{...}` on the main checkout (they are not in this worktree),
commit. Also note `no-mistakes` in `~/.claude/skills/` is required by the global
`CLAUDE.md` push rule and is not in dotfiles at all; decide separately whether to vendor
it or document its install step in the README.

## Test

`./tests/run.sh` still green. On a scratch `HOME`, run dotbot with the config and check
every `~/.claude/skills/*` link resolves.

## Comments

2026-09-28: Done on feat/whiska-boundary: the eight skill dirs copied from the main checkout and added; tests/install-links.test.sh now fails if any install.conf.yaml link source is missing. Also found and removed the `~/.claude.json: .claude.json` link — the source never existed and ~/.claude.json is Claude Code's live state (tokens), which must not be in dotfiles. no-mistakes still not vendored; separate decision.
