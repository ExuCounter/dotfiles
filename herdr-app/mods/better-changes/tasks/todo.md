# Review queue: tasks

Plan: [`plan.md`](plan.md). Run tests from `herdr-app/mods/better-changes` with `node --test git/`.

## Task 1: `reviewQueue` and the note data it needs
**Description:** a pure rule for what goes in the queue, in what order and which side each item
waits on, plus the data from GitLab it runs on.

**Acceptance criteria:**
- [ ] It follows the spec's table: open resolvable threads from anyone, plain comments from
      people other than me that I haven't answered, and no bot plain comments.
- [ ] Order: waiting on me first, oldest first, then waiting on them. Each item carries
      `waitingOn: "me" | "them"`.
- [ ] Every note has `authorId`, `bot`, and a `name` that falls back to `@username` when GitLab
      masks it as `****`. `me` is read once per host from `glab api user`.

**Verification:**
- [ ] Test first, `node --test git/`: the table's rows, the order, a thread with several
      replies, and the masked name.
- [ ] Manual: the result of `reviewQueue` on !9271's real discussions is exactly the 3 open
      CodeRabbit threads.

**Dependencies:** none
**Files:** `git/review-queue.js`, `git/review-queue.test.js`, `git/merge-request.js`
**Scope:** S

## Task 2: MR-wide counts in the footer and the sidebar chip
**Description:** the footer and the sidebar chip count the queue, not the open file.

**Acceptance criteria:**
- [ ] The footer reads `Threads n open · m waiting on them` over the whole MR. The "waiting on
      them" part shows only when m > 0.
- [ ] better-sidebar's chip counts with the same rule, imported from better-changes (spike).
      If herdr can't import across mods, it uses a copy that the test also runs.
- [ ] The chip says "waiting on them" where it said "answered".

**Verification:**
- [ ] `node --test git/` passes.
- [ ] Manual: on !9271 the footer and the chip both say 3, whichever file is open.

**Dependencies:** 1
**Files:** `views/threads.js`, `../better-sidebar/git/mr-inbox.js`, `../better-sidebar/views/inbox.js`
**Scope:** S–M

## Checkpoint A
- [ ] Tests pass, the mods reload without errors, and the counts match on !9271.

## Task 3: queue panel and card
**Description:** the panel under the diff shows the current queue item as a card. It replaces
the per-file "Every thread on <file>" list.

**Acceptance criteria:**
- [ ] The card shows where the item is, its state (Open / waiting on them), its position `i / n`,
      the first note clamped to about 8 lines with "Show all", the latest reply in full, and
      "n earlier replies" folded.
- [ ] `t` shows or hides the queue panel. An empty queue says "No open threads".
- [ ] Bodies are cleaned of bot HTML comments, and no author shows as `****`.

**Verification:**
- [ ] Manual on !9271: each of the 3 cards renders, and a long CodeRabbit finding is clamped
      and expands. A screenshot goes to the person.

**Dependencies:** 1
**Files:** `views/threads.js`, `views/comments.js` (where the panel mounts)
**Scope:** M

## Task 4: moving through the queue
**Description:** step through the queue, landing on each item's line.

**Acceptance criteria:**
- [ ] With the panel open, `cn` / `cN` step through the queue (wrapping round), opening the
      item's file with the cursor on its line. With the panel closed, they behave as today.
- [ ] A line the changes-only diff doesn't show switches the diff to the whole file at that
      line. An outdated or MR-level item shows its card with "not in this diff".
- [ ] Clicking the sidebar's "n threads" chip (or an MR with open threads) opens the queue on
      item 1 (`queue: true` on `better-changes.open-thread`).

**Verification:**
- [ ] Manual on !9271: the chip goes to 1 / 3 at `dashboard.ex:13`, `cn` to `index.tsx:44`,
      then `index.test.tsx:181`, then wraps round.

**Dependencies:** 3
**Files:** `views/threads.js`, `views/vim.js`, `../better-sidebar/views/inbox.js`
**Scope:** M

## Checkpoint B
- [ ] The whole queue works end to end on !9271 with no actions yet. Show the person before
      going on.

## Task 5: Reply, Resolve, Fix with agent
**Description:** the card's buttons and their keys.

**Acceptance criteria:**
- [ ] Reply `r` opens the box under the card, and ⌘↩ posts. The item moves to "waiting on
      them" after the re-read.
- [ ] Resolve `x` resolves on GitLab and moves on to the next item. The count drops.
- [ ] Fix with agent `F` adds the thread to the review comments (`threadToAgent`). The buttons
      are pill buttons with icons, styled like the bar's `BarButton`.

**Verification:**
- [ ] Manual: reply on, and resolve then reopen, one !9271 thread (or a scratch MR's). Fix with
      agent shows in the review comments bar.

**Dependencies:** 3, 4
**Files:** `views/threads.js`, `views/vim.js`, `views/ui.js` (only if a button variant is missing)
**Scope:** M

## Task 6: Ask AI on a thread
**Description:** ask the reviewer Claude whether a thread is right and what the fix would be,
with the answer on the card.

**Acceptance criteria:**
- [ ] `a` with the card focused sends the thread (the notes and its `path:line`) as a question
      to the running reviewer, or starts one. The question asks for "valid? fix?" and nothing
      else.
- [ ] The card shows "Asking…", then the answer. The answer is keyed by thread id in a
      `threadAnswers` list.
- [ ] `git status` doesn't change.

**Verification:**
- [ ] Manual on !9271 item 1: the answer appears on the card, and `git status` is the same as
      before.

**Dependencies:** 3
**Files:** `views/reviewer.js`, `views/threads.js`, `views/vim.js`
**Scope:** S–M

## Task 7: help, version, spec closed out
**Acceptance criteria:**
- [ ] `views/help.js` lists the queue keys (`t`, `cn`/`cN` in queue mode, `r`, `x`, `a`, `F`).
- [ ] `mod.json` is version 2.6.0, staged without the unrelated uncommitted changes.
- [ ] The spec matches what was built.

**Verification:** `?` in Better Changes shows the keys.
**Dependencies:** 5, 6
**Files:** `views/help.js`, `mod.json`, `SPEC-review-queue.md`
**Scope:** XS

## Task 8: the inbox tree for Mine
**Acceptance criteria:**
- [ ] Repo → compact MR row (title, `!iid`, icons for pipeline, approval and threads; a failed
      pipeline or a conflict in red) → the queue items as `● path:line`, with waiting on them
      dimmed.
- [ ] The status line is one small dim line. An MR with items starts expanded, one without
      collapsed, and each can be toggled.
- [ ] The MR's status carries its queue items (path, line, waitingOn, thread id), not only
      the counts.

**Verification:** `herdr-app check` passes. Manual: !9271 shows its 3 rows, and a screenshot
goes to the person.
**Dependencies:** 2
**Files:** `../better-sidebar/git/mr-inbox.js`, `../better-sidebar/views/inbox.js`
**Scope:** M

## Task 9: Reviews tab in the tree; a click opens the queue
**Acceptance criteria:**
- [ ] Reviews: a "review · not approved at head" row, then the threads I'm in that have
      answers.
- [ ] Clicking a child row opens that item's card in the Better Changes queue
      (`better-changes.open-thread` with the thread id), and clicking the MR row opens the
      queue on item 1.

**Verification:** manual: a click on `index.tsx:44` lands on 2 / 3 with the cursor on line 44.
**Dependencies:** 4, 8
**Files:** `../better-sidebar/views/inbox.js`, `views/threads.js`
**Scope:** S–M

## Checkpoint D
- [ ] Phase 4 is checked live and shown to the person.

## Checkpoint C
- [ ] All 9 success criteria in the spec are checked live.
- [ ] Review agents (correctness and architecture) say READY. Then report to the person, who
      decides on the commit.
