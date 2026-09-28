# 01 — Whiska writes the marker rule into its per-project CLAUDE.md block

Status: decided-A
Repo: whiska (re-file there once decided)
Blocked by: none. Blocks: 02 (second half).

## Question

ADR-0017 says `whiska init` writes a `<!-- whiska:start -->` ... `<!-- whiska:end -->`
block into the project's `CLAUDE.md` and `whiska update` replaces exactly that block.
`Whiska.Install` does not do this today: it writes `settings.json`, the shim, the
statusline script and one skill. The marker rule therefore lives only in dotfiles'
global `CLAUDE.md`, and it is stale there.

Should the marker rule move into that block (Whiska owns it, per project), or stay in the
global file with Whiska's block only adding the main-session rule?

## Options

**A. Move it (recommended).** The block carries: the marker spelling and its two values,
"always the last line", "put the whole content in the body", "never expect the main
session to read your pane", and the main-session rule from ADR-0017 ("present a
delivered question faithfully, then wait"). Global `CLAUDE.md` drops its section once
`whiska update` has run in every repo that has mice.
- For: one owner. A Whiska change to the marker (say, the invisible-character prefix
  from the spec) ships with `whiska update` and never waits on dotfiles. Repos without
  Whiska stop being told to emit a marker nobody reads. This is what ADR-0016 and
  ADR-0017 already decided.
- Against: a repo that has worktrees but was never `whiska init`-ed gets no marker
  rule. That is correct: no owl reads it there.

**B. Keep it global, block adds only the main-session rule.**
- For: zero sequencing; nothing to wait for.
- Against: two files describe one protocol forever, which is the problem this proposal
  exists to end.

## Scope for the Whiska ticket (if A)

- `Whiska.Install` gains `claude_md_block/0` and a merge that inserts or replaces the
  marked block in `CLAUDE.md`, creating the file if missing, touching nothing else.
- `whiska init` writes it; `whiska update` rewrites it (ADR-0016's "opt-in per repo").
- `whiska doctor` gains a line: block present and current, or `fix: whiska update`.
- Content: ADR-0017's rule list plus the marker section currently in dotfiles' global
  `CLAUDE.md`, rewritten to say delivery exists.
- Tests at the same seam as the existing settings merge (pure value in, pure value out).

## Comments

2026-09-28: User chose A: the marker rule moves into Whiska's per-project CLAUDE.md block. Re-file in the Whiska repo. Until it ships, dotfiles' global CLAUDE.md keeps a corrected copy with a note saying it will move.
