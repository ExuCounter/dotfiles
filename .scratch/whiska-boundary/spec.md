# Whiska boundary: what dotfiles keeps, what moves into Whiska

Status: proposed
Date: 2026-09-27
Branch: `feat/whiska-boundary` (dotfiles). Whiska lives at `~/Desktop/projects/whiska`.

## Problem Statement

The dotfiles repo still carries text that belongs to Whiska: the `[worktree-status: ...]`
marker protocol, the doorstep path, "how to check on a worktree", and the claim that
nothing delivers a question to the main session. Whiska's `main` now delivers
(ADR-0008 built, README "Status: delivery"), so the global `CLAUDE.md` and two skills are
already wrong. Meanwhile Whiska has not built the part that would let dotfiles drop that
text: `whiska init` does not yet write the `<!-- whiska:start -->` block into a project's
`CLAUDE.md` (ADR-0017), so today the marker rule reaches mice only through the global
`CLAUDE.md`.

Two repos are describing one protocol. Each edit to Whiska risks leaving dotfiles stale,
and each dotfiles instruction that names a Whiska internal (doorstep, `.collected`,
`herdr agent prompt` as the reply path) is a place Whiska cannot change without also
editing dotfiles.

## The boundary rule

One sentence, to be applied to every future edit on either side:

> **dotfiles owns how the person and herdr work. Whiska owns how mice, questions and the
> main session talk to each other.** dotfiles may point at Whiska by name; it may not
> restate Whiska's protocol.

Concretely:

| Belongs to dotfiles | Belongs to Whiska |
|---|---|
| Human-facing writing rules (plain language, cold re-entry, one question at a time) | The marker: its spelling, the two values, "always the last line" |
| When to spawn vs route vs work in place (the "Worktrees" decision tree) | What happens after a turn ends: doorstep, collection, delivery, reply |
| herdr mechanics: `spawn-worktree`, `send-to-worktree`, `drop-worktree`, `open-workspace` | Per-command slash skills: `/whiska-questions`, `/whiska-reply`, `/whiska-close` |
| The `worktrees/<branch>` layout convention (Whiska consumes it, ADR-0030) | Mouse identity, modes, containment rules, statusline segment |
| Frontend preview gate, TDD, verify-before-done, the no-mistakes push gate | Rules for the main session when a question is delivered (ADR-0017's last rule) |
| Global hooks: glow preview, hunk review, herdr agent state | Per-project hooks: `.claude/settings.json`, `whiska.sh` shim, project statusline |

One contract crosses the line and must be written down on both sides: **worktrees live at
`<main-checkout>/worktrees/<branch>/`**. dotfiles' `spawn-worktree` creates that layout;
Whiska's `Layout` module derives worktree root and main checkout from it and nothing
else. Changing either side's path breaks identity and containment silently.

## Audit

### Global `CLAUDE.md` (`claude/CLAUDE.md`, linked to `~/.claude/CLAUDE.md`)

| Section | Verdict | Why |
|---|---|---|
| Plain language | keep | Human-facing. Whiska's CONTEXT.md/ADRs do not cover it. |
| Context re-entry | keep | Human-facing. Whiska's spec explicitly says its mouse-facing block "should hold the same standard"; that is Whiska restating it for mice, not a reason to move this. |
| Worktrees (steps 1 to 4) | keep, one edit | herdr workflow. Step 3 names the marker spelling; replace with "end with the worktree-status marker (Whiska's rule)". |
| **Worktree status marker** | **move to Whiska** | Entirely Whiska protocol, and stale: says "nothing delivers this to the main terminal right now" and "the half that delivers ... is not built yet". Delivery shipped on Whiska `main` (ADR-0008, README). Belongs in the `<!-- whiska:start -->` block that `whiska init` writes per project (ADR-0016, ADR-0017). Until Whiska writes that block, keep a corrected, shortened version here (see issue 02). |
| Frontend changes | keep, one edit | dotfiles gate. The line "its `needs-decision` marker should carry the Artifact URL" stays but should say "the worktree-status marker" without restating spelling. |
| TDD is mandatory | keep | Whiska's `CLAUDE.md` inherits it by name ("Inherited, not repeated here"). |
| Verify before claiming done | keep | Same. |
| Pushing via no-mistakes gate | keep, flag | dotfiles. Whiska's future push approval (ADR-0012, not built) will sit at PreToolUse beneath this gate. No conflict today; revisit when ADR-0012 lands. |
| Orchestrating the gate | keep | Generic. |

What must NOT be dropped even though it looks Whiska-ish: the "Worktrees" decision tree.
ADR-0021 says spawning happens through a conversation, not a `whiska spawn` command. That
conversation is steered by this section. It is the dotfiles half of ADR-0021.

### Project `CLAUDE.md` (dotfiles root)

Keep as is (issue tracker + domain docs pointers). Two things sit beside it uncommitted in
the main checkout: `.claude/settings.json`, `.claude/hooks/whiska.sh`,
`.claude/hooks/whiska-statusline.sh`, `.claude/skills/whiska-questions/` — the output of
`whiska init`. ADR-0016 says commit them. Decision in issue 06.

### Skills tracked in dotfiles (`claude/skills/`, wired by `install.conf.yaml`)

| Skill | Verdict | Detail |
|---|---|---|
| `spawn-worktree` | keep, trim | herdr mechanics stay. The "Checking on it — nothing will interrupt you" section is Whiska protocol and stale (says nothing delivers; teaches `ls .git/whiska/doorstep/*.json` and `herdr agent prompt` as the reply path, which ADR-0005 replaced with `whiska reply <id>`). Replace with two lines: questions from this worktree arrive through Whiska when the repo is set up; `whiska doctor` says whether it is. Add the layout contract note. |
| `send-to-worktree` | keep, trim | Same stale section, same cut. Routing via `herdr agent prompt` is correct and stays: it is a new prompt, not a reply, and ADR-0037 handles the superseded question. |
| `drop-worktree` | keep, flag | herdr. Whiska's spec has a future `whiska cleanup` with mechanical "never tear down unlanded work" checks. When that exists, decide whether `drop-worktree` calls it or is replaced. Not now. |
| `open-workspace` | keep | Pure herdr. No Whiska relation. |
| `frontend-preview` | keep, one edit | Step 7 spells the marker. Change to "end with the worktree-status marker; the Artifact URL goes in the body and the marker line". |
| `grilling`, `grill-me` | keep | Generic (mattpocock). |
| `handoff`, `tdd`, `to-spec`, `research` | keep | Generic (mattpocock). |

### Skills listed in `install.conf.yaml` but NOT tracked in git

`c4-architecture`, `codebase-design`, `command-creator`, `domain-modeling`,
`domain-name-brainstormer`, `lesson-learned`, `wayfinder`, `writing-for-agents` are
symlink targets in `install.conf.yaml` and exist in the main checkout as untracked dirs
(`??`). A fresh `./install` would create dangling links. Whiska's own `CLAUDE.md` depends
on three of them by name (`domain-modeling`, `lesson-learned`, and the C4 rules from
`c4-architecture`), and its `post-push-reflect.sh` hook asks for two of them after every
push. This is the clearest "help Whiska" item in dotfiles: issue 05.

### Skills in `~/.claude/skills/` not managed by dotfiles

- `no-mistakes`: the global `CLAUDE.md` push rule depends on it; it is not in dotfiles at
  all. Out of scope here, but the same gap as above. Noted in issue 05.
- `use-herdr`: generated from the herdr binary by `./install`. Fine.
- `synced/`: claude.ai-synced. Not ours.

### Whiska-owned skills

Only `/whiska-questions` is installed today. ADR-0022 puts `reply` in the "used by your
session" group, so `/whiska-reply` and `/whiska-close` belong in `Whiska.Install.@skills`.
Until they exist, the main session has to compose `whiska reply 12 "..."` from the
delivered line, which is the failure mode ADR-0022 was written to avoid. Issue 04.

### Hooks and settings

| Item | Verdict |
|---|---|
| Global `Stop` → `hunk-review.sh`; project `Stop` → `whiska.sh stop` | Both fire, independent. Fine. |
| Global statusline; project statusline wraps it | Compatible by design (ADR-0027). Fine. |
| `SessionStart` → `herdr-agent-state.sh` | herdr-managed file, present. Fine. |
| `~/.claude/hooks/herdr-worktree-notify.sh`, `herdr-worktree-resume.sh` | **Dangling symlinks**, leftover from the relay removal. dotbot's `clean: ["~"]` does not reach `~/.claude/hooks`. Issue 07. |
| `settings.json` `worktree.baseRef: "fresh"` and `.gitignore` `.claude/worktrees/` | Claude Code's native worktree feature creates `.claude/worktrees/<name>`. Whiska's `Layout` only recognises `worktrees/<branch>`, so a native worktree is neither a mouse nor the main checkout: its `Stop` hook is a no-op and containment does not apply. Issue 08 asks which side gives. |

### Memory

`project_worktree_relay_correlation_gap.md` in this project's memory describes a gap in
the deleted bash relay. ADR-0005 (answers keyed to a question id) closes it. Rewritten in
this session to point at Whiska instead.

## Sequencing

The move is not a single cut. Order matters because ADR-0009 makes a missing marker
"deliver as unmarked": if dotfiles drops the marker rule before Whiska's block carries it,
every mouse turn still arrives, but `done` reports become questions that wait for a
reply, and the `needs-decision` pointer text is lost.

1. **Now, dotfiles (this branch):** correct the stale claims without moving anything.
   Global `CLAUDE.md` marker section says delivery exists and points at `whiska
   questions` / `whiska reply`. `spawn-worktree` and `send-to-worktree` lose the doorstep
   walkthrough. Issues 02, 03, 07.
2. **Whiska:** `whiska init` and `whiska update` write the `<!-- whiska:start -->` block
   with the marker rule and the main-session rule (ADR-0017). Add `/whiska-reply` and
   `/whiska-close` (ADR-0022). Issues 01, 04. These are Whiska tickets; they are written
   here so the proposal is complete, and should be re-filed in Whiska's tracker.
3. **dotfiles, after 2 ships and `whiska update` has run in each repo:** delete the
   marker section from the global `CLAUDE.md` entirely; the global file then never
   mentions Whiska except as the thing that delivers. Second half of issue 02.
4. **Independent of the above:** track the untracked skill dirs (05), decide whether
   dotfiles commits its own `whiska init` output (06), decide native worktrees (08).

## Out of scope

- Rewriting Whiska's CLAUDE.md block content. ADR-0017 and the spec already list the
  rules; the ticket here is "write it", not "redesign it".
- The no-mistakes gate vs Whiska's future push approval (ADR-0012). Nothing to decide
  until ADR-0012 is built.
- `drop-worktree` vs a future `whiska cleanup`.
- Whether `spawn-worktree` should set a mouse's mode (`whiska mode sniff`) at creation.
  Worth a Whiska ticket later; ADR-0021 puts that judgment in the conversation, and the
  skill is where the conversation ends up. Not needed for the boundary.

## Open decisions

Three, in the order they block work. Each is its own issue with the options spelled out.

1. Does the marker rule move into Whiska's per-project `CLAUDE.md` block, or stay global
   with Whiska's block only adding to it? (issue 01, recommendation: move)
2. Does dotfiles commit its own `whiska init` output? (issue 06, recommendation: yes)
3. Native Claude Code worktrees: disable in dotfiles, or teach Whiska the layout?
   (issue 08, recommendation: disable)
