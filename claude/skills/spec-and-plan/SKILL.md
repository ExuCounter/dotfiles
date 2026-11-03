---
name: spec-and-plan
description: Write a spec and a build plan, or for a bug a research document, and build only on the person's ok. Use only when a task, a CLAUDE.md or the person asks for a spec, a plan or a bug's research document; never by default.
---

The person reads every line before any code. Write so the whole change can be judged in one sitting: what users see in the spec, how it is built in the plan, the proof of a bug in the research document.

## Steps

1. **Read the code**, then settle the costly choices with the person (the `grilling` skill's costly test).
2. **Write the files** below: a spec and a plan, or for a bug a research document and a plan.
3. **Ask for an ok on both**, naming each file's absolute path and what to review in it ("the two decisions, then the first failing test"). Done when the person says ok. Any other reply revises the files and asks again.
4. **Build to both**, failing test first. A costly choice found mid-build, a change to the plan, or straying from the spec stops the build and goes to the person as a question before it is built.

## Where the files go

The repo's CLAUDE.md names a place → there. Otherwise the worktree's own git folder, where git never tracks them and they go with the worktree: `$(git rev-parse --git-dir)/spec.md`, `plan.md`, `research.md`. Name the absolute path in the message, so the person can open it in revdiff.

## Every file

- Each fact appears once across spec, plan and research document, and only if the person needs it: a section never retells another, the task, or the person's answers.
- One screen each. Lists, never tables. A markdown link stays on one line: the person comments by selecting one.

## The spec

A `# ` title, then up to four headings, in words:

- **Problem**: why, in two lines at most, with what the task did not say.
- **What changes for users**: every behaviour a user or calling program sees differently, anything hidden, dropped, skipped or turned from an error into silence included, and each limit the task or the person's answers set (a dependency, an approach, "never log the secret"); or "Nothing." Always present: it is where a fix that drops something users see gets written down.
- **Decisions**: only choices you made yourself, and each ADR whose decision changes, one line each: "X, not Y: why".
- **Out of scope**: only what the task could be read to include.

A heading with nothing under it is left out, but What changes for users.

## The build plan

The approach, as a senior engineer writes it before starting: the shape of the change, never a step list.

- Where it lands: one line per module. Docs, comments and tests the change touches go unlisted.
- The approach turned down and why, unless the spec or research document names it.
- Signatures, data shapes (a column, a JSON field, a 3-5 line file example) and the first failing test, as code blocks. Function bodies stay in the build.

## A bug: the research document

A bug is something working wrong whose fix changes nothing beyond it; a fix that changes more goes the spec way. Reproduce it in a failing test first: the test is the evidence of the cause. Then the research document, shown by example:

- A `# ` title.
- Before and after: the real command and its real output (the failing test's run), the line as it is and as it will be.
- The cause, with a small worked case using real values.
- The fix. Options with their trade-offs and a pick only when there is a real choice; one obvious fix is the cause, the fix and the test.

A sentence or so around each example says what to notice. A bug that will not reproduce stops here: the document, what was tried, and no fix.
