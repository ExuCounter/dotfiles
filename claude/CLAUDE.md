## Plain language

Write in simple, plain terms — short sentences, common words, no filler or hedging.
Say the thing directly instead of padding it with corporate-speak or unnecessary
qualifiers. If a technical term is unavoidable, explain it in one short clause the
first time it comes up. Cut anything that doesn't change what I'd do next.

<!-- Sourced from https://github.com/jasonku09/agents-md-snippets -->

## Context re-entry (multi-project juggling)

I am juggling several projects, each with several concurrent sessions, and have usually lost
the thread by the time I return to any one of them. Write every user-facing message for cold
re-entry — assume I remember nothing from the scrollback:

- **Open with a recap.** Before any summary, decision point, or question: 2–3 plain sentences on
  what we were just working on, why, and where it stands now.
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
   "Frontend changes" below. This happens inside the worktree too, and the response
   body and its worktree-status marker should carry the Artifact URL.

This applies whenever `HERDR_ENV=1`; outside a herdr session `spawn-worktree`'s own
preconditions will refuse, so just grill and work in the current checkout instead.
Skip steps 2 and 3 for small, contained edits (a one-line
config tweak, a quick question that turns into a small fix) or when told to work in
place.

After the work is merged, use `drop-worktree` to clean up. For the next task, spawn a
fresh worktree from the latest base branch — don't reuse old trees.

## Worktree status marker

If you're running inside a spawned or routed worktree (not the user's main terminal),
end every response with one plain marker line, so what happened is on the record rather
than guessed from herdr's screen-detected idle/blocked state. Whiska reads exactly this
marker to classify the turn, so the spelling matters:

- `[worktree-status: done]` — the task is fully finished, nothing needed from the user.
- `[worktree-status: needs-decision] <a short pointer, in one line>` — you're stopping
  because only the user can decide something. If it's a single short question, put it
  right there. If it's a `grilling` round with several questions, write something like
  "3 questions ready, see above" and leave the actual questions in the response body.

Always the last line, always exactly one of the two. Don't add this in the user's main
terminal — only in a session that was spawned into or routed to a worktree.

Whiska collects your whole final message and delivers a one-line pointer to the main
session when that repo has been `whiska init`-ed, the owl is running, and a main
session is recorded (`whiska doctor` says which of those is missing). The person reads
it with `whiska questions <id>` and answers with `whiska reply <id>`. A forgotten marker
still gets delivered, as an unmarked question. Two rules follow:

- Put the complete content in the response body — every question, every option, every
  recommendation, spelled out. Your whole final message is what gets stored; the marker
  is only the pointer.
- Make the body self-contained, the same way the "Context re-entry" rule asks. Whoever
  reads it is in a different terminal with none of this session's scrollback, possibly
  much later.

Never ask the main session to read your pane's scrollback, and never expect it to.
Claude Code runs on the terminal's alternate screen, so `herdr pane read` returns a
truncated tail no matter what `--lines` it passes. Storing the whole message is what
makes that irrelevant.

This section moves into the block `whiska init` writes into each project's `CLAUDE.md`
once Whiska ships it (Whiska ADR-0017); it is kept here until then.

## Frontend changes — preview before building

When a task changes what I'd see in a browser, do not go straight to code. Use the
`frontend-preview` skill first: it captures the current state, mocks up 2-3 directions
using the project's real design tokens, and publishes one Artifact page with before,
after, and the options side by side. Then it stops and waits for me to pick.

The test for whether this applies is one question: **would a screenshot of the app look
different after this change?** New page, redesign, layout, component, styling, or copy
on a visible surface — yes. Renamed route, query tuning, a test, build config — no, even
if the request mentions a UI word in passing.

Skip it — out loud, in one line, never silently — when the change has exactly one
sensible form (a typo, a colour I already named), when I gave you a mock or screenshot
to match, or when I say to just build it.

While waiting for my pick, write **no** implementation code, not even the scaffolding.
Pre-building your recommended option skips this step while appearing to follow it. This
gate comes before the TDD cycle below: pick the direction first, then write the failing
test for it.

## TDD is mandatory

Every change follows **failing test first → implement → verify**:
1. Write the test(s) that capture the desired behavior and watch them **fail** (red).
2. Implement the minimum to make them pass.
3. Run the suite + typecheck and confirm green.

Don't write implementation before a failing test exists. When fixing a bug, reproduce it with a
failing test first.

## Verify before claiming "done"

Never report something as working without running it. "Done" means: relevant tests green,
typecheck clean, and — for user-facing flows — exercised end to end (e.g. Playwright for web
flows). If tests fail or a step was skipped, say so plainly with the output.

## Pushing committed work — use the gate when it's set up

Before pushing any committed work, check whether this repo has the
[no-mistakes gate](https://github.com/kunchenguid/no-mistakes) initialized:
`no-mistakes status` — if it reports "repo not initialized", the gate isn't
set up here and a plain `git push` is fine (don't silently run `no-mistakes
init` yourself; ask first if you think it should be). If it *is* initialized,
drive the push through the gate instead of a plain `git push` — invoke the
`no-mistakes` skill (or `/no-mistakes`) rather than pushing directly to
`origin`, so the change actually gets reviewed/tested before it ships.

## Orchestrating the gate (builder/driver split)

Targets the [no-mistakes gate](https://github.com/kunchenguid/no-mistakes) — adapt if using a
different gate. The agent that *built* a feature sits on a huge context; if that same agent
drives the review gate, that context gets resent on every monitoring turn. A fresh, cheap driver
instead makes a park→decide→resume roundtrip cost ~30k tokens instead of ~200k.

- **Builders never drive the gate.** A builder agent builds, commits on its branch, and ends its
  task with a `HANDOFF: INTENT` paragraph — a thorough statement of what changed and why, for
  the reviewer. Its large transcript is read once and never resumed for gate-driving.
- **A fresh tiny driver agent per worktree** (cheap model, few-k-token context) runs the gate:
  it starts the review with the handed-off intent, monitors progress, and answers the gate's
  questions.
- **Gate rules for the driver:** apply auto-fixable findings; approve info-only findings; for
  anything that needs a human decision, PARK — quote the finding verbatim and end the task so
  the orchestrator can relay it to me, then resume the driver with my decision. Resume a
  builder only when a finding needs real code fixes.
- Never end a subagent's turn while a gate run is active — its background processes are
  orphaned the moment the turn ends.

**Bonus — cross-provider review:** having a different provider review than the one that built
(e.g. Claude Code implements, Codex reviews, or vice versa) catches a different distribution of
bugs, and spreads the token load across two subscriptions.
