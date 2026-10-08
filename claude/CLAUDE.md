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
- **No callbacks.** No invented codenames or abbreviations, and nothing like "the earlier
  fix" or "option B from before" — restate the thing in place, every time.
- **One question at a time.** When a summary or decision point holds several open questions or
  next steps, say so up front ("three decisions are waiting; here's the first"), then present
  only the first and wait for the answer before raising the next. Never dump them all at once —
  it's too much mental load.
- **Anchor the work.** Name the project, branch, and PR when reporting status — several other
  sessions look just like this one.

## Frontend preview

If a screenshot of the app would look different after a change, run the
`frontend-preview` skill — but only in a build session, after the spec is written and I
have approved it, and before any implementation code. Never while grilling, never before
the spec, never while investigating. Invoking it is how you ask; don't ask permission.
Borderline counts as yes. The skill itself says when to skip.

## Verify before claiming "done"

Never report something as working without running it. "Done" means: relevant tests green,
typecheck clean, and — for user-facing flows — exercised end to end (e.g. Playwright for web
flows). If tests fail or a step was skipped, say so plainly with the output.
