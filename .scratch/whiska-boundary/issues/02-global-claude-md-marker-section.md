# 02 — Global CLAUDE.md: fix the stale marker section now, delete it after 01

Status: part-1-done
Repo: dotfiles
Blocked by: none for part 1; part 2 blocked by 01.

## Part 1 (now)

The "Worktree status marker" section in `claude/CLAUDE.md` says:

- "Nothing delivers this to the main terminal right now."
- "the half that delivers a collected question to the main session is not built yet"
- "Either way, I come to you — you are never pinged."

All three are false on Whiska `main`: a collected question is typed into the main
session as `🐱 whiska #N ...` when that pane is idle (ADR-0008), and `done` is delivered
too (ADR-0009 revised 2026-09-27).

Replace the section with the shortest true version:

- The two marker lines, spelling unchanged.
- "Whiska collects your whole final message and delivers a one-line pointer to the main
  session; the person reads it with `whiska questions <id>` and answers with
  `whiska reply <id>`. Delivery needs the owl running and a main session recorded;
  `whiska doctor` says which."
- Keep: full content in the body, self-contained body, never ask the main session to
  read the pane.

Also in the "Worktrees" section step 3 and the "Frontend changes" section: replace the
spelled-out marker with "the worktree-status marker" so only one place spells it.

## Part 2 (after 01 ships and `whiska update` has run in each repo with mice)

Delete the section. The global file keeps only the pointer in "Worktrees" step 3.

## Test

`tests/` has no test for CLAUDE.md content and does not need one. Verify by reading
the rendered file and by one mouse turn in a `whiska init`-ed repo: `whiska questions`
shows the question with the right marker classification.

## Comments

2026-09-28: Part 1 done on feat/whiska-boundary: section rewritten to say delivery exists, points at whiska questions/reply/doctor; Worktrees step 3 and Frontend changes no longer spell the marker. Part 2 (delete the section) waits on issue 01.
