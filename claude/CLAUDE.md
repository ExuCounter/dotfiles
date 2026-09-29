## Plain language

Write in simple, plain terms — short sentences, common words, no filler or hedging.
Say the thing directly instead of padding it with corporate-speak or unnecessary
qualifiers. If a technical term is unavoidable, explain it in one short clause the
first time it comes up. Cut anything that doesn't change what I'd do next.

Write every piece of output on purpose. Before writing, decide what the reader needs,
then produce only that: the smallest message, file, comment, or commit body that does
the job. Every extra line costs me reading time and costs tokens, so do not restate the
task, do not narrate what you did unless asked, and do not add sections a reader would
skip. Prefer one plain sentence over a formatted block when the sentence is enough.

<!-- Sourced from https://github.com/jasonku09/agents-md-snippets -->

## Context re-entry (multi-project juggling)

I am juggling several projects, each with several concurrent sessions, and have usually lost
the thread by the time I return to any one of them. Write every user-facing message for cold
re-entry — assume I remember nothing from the scrollback:

- **The first line is the recap.** One sentence that says what we were working on and
  where it stands now, so a decision or question that follows makes sense cold.
- **Plain language.** No invented codenames, abbreviations, or callbacks like "the earlier fix"
  or "option B from before" — restate the thing in place, every time.
- **Self-contained questions.** When asking me to decide something, the question itself
  must carry everything needed to answer it: the background, the options, the tradeoffs, and
  your recommendation. Never require scrolling back.
- **One question at a time.** When a summary or decision point holds several open questions or
  next steps, say so up front ("three decisions are waiting; here's the first"), then present
  only the first and wait for the answer before raising the next. Never dump them all at once —
  it's too much mental load.
- **Anchor the work.** Name the project, branch, and PR when reporting status — several other
  sessions look just like this one.
- **End with the next action.** Close long updates with the single thing waiting on me,
  or say explicitly that nothing is.

## Worktrees

When I describe a real feature or fix — one that touches multiple files or will take
more than a few minutes:

1. **Check for an existing worktree first — before anything else, including grilling.**
   Run `herdr worktree list` right away. git can't have two worktrees on the same branch
   anyway, so the real question is whether this idea continues a feature already being
   built in an active worktree (a sub-part, refinement, or follow-up that would ship on
   the same branch/PR) or is a separate, independently-shippable unit of work.
   - Continues an existing worktree → use `send-to-worktree` to route the raw idea into
     that session right now. Let that session grill me further if it needs to — don't
     grill here first, and don't read any code here first.
   - Separate unit of work, or no active worktree matches → continue to step 2.
   - Unclear which case applies → ask me directly, don't guess.
2. **Spawn the worktree immediately** — before doing anything else, even before reading
   any code, and even if the brief is still vague. Don't grill me here in the main
   terminal first; a thin brief is not a reason to keep this terminal busy. Use whatever
   name the raw request suggests for the branch — it doesn't need to be final.
3. **If the brief is thin, grill from inside the worktree.** Once you're in the new
   session, if it's missing real detail (what "done" looks like, which part of the app,
   what data it uses, edge cases) — use the `grilling` skill there, ending each round
   with the worktree-status marker (see "Worktree status marker") so the question is
   on the record for me to pick up. Do all investigation and grilling in the new
   worktree, not just the eventual edits, so my main terminal never runs a single
   command for this task; it stays free for something else.
4. **If it's a frontend change, preview it visually before implementing** — see
   the frontend-preview rule. This happens inside the worktree too, and the response
   body and its worktree-status marker should carry the Artifact URL.

This applies whenever `HERDR_ENV=1`; outside a herdr session `spawn-worktree`'s own
preconditions will refuse, so just grill and work in the current checkout instead.
Skip steps 2 and 3 for small, contained edits (a one-line
config tweak, a quick question that turns into a small fix) or when told to work in
place.

After the work is merged, use `drop-worktree` to clean up. For the next task, spawn a
fresh worktree from the latest base branch — don't reuse old trees.

## Worktree status marker and reports

Whiska ships these now. In a repo that has run `whiska init`, the block in that repo's
`CLAUDE.md` says how a worktree session ends its turn (an invisible marker line, three
U+2063 characters for finished, two for a decision, with the pointer sentence on the line
above), how a message reaches the person, and how every session writes its message.
Follow that block. In a repo without it, end a worktree session's turn with the same
invisible marker and write the message the same way: short, outcomes not mechanics,
verified not assumed, one decision or "Nothing is waiting on you".

## Verify before claiming "done"

Never report something as working without running it. "Done" means: relevant tests green,
typecheck clean, and — for user-facing flows — exercised end to end (e.g. Playwright for web
flows). If tests fail or a step was skipped, say so plainly with the output.
