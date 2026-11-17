# Implementation plan: review queue in Better Changes

Spec: [`../SPEC-review-queue.md`](../SPEC-review-queue.md). Tasks: [`todo.md`](todo.md).

## Overview
The MR's open threads become one queue in Better Changes, worked through one card at a time
with Reply, Resolve, Ask AI and Fix with agent. The footer and better-sidebar's chip count the
same items. The slices go from the rule outwards: the rule, the counts, the card, moving through
the queue, then the actions.

## Architecture decisions
- **One rule, one file.** `git/review-queue.js` holds `reviewQueue(threads, me)`, a pure
  function with no herdr imports, so `node --test` can run it and both mods can use it. It
  decides what goes in the queue, its order, and the waiting-on-me / waiting-on-them split.
- **Notes keep who wrote them.** `readThreads` adds each note's author id and a bot flag (the
  `isBot` test better-sidebar uses), and the thread's `resolvable`. `me` comes from
  `glab api user` once per host and is cached in shared state, as better-sidebar does with
  `this.user`.
- **The queue panel replaces the per-file list** in `views/threads.js`. The strip on the line
  and the "thread on this line" view stay as they are.
- **Ask AI reuses the reviewer's question path** (`sendQuestion` → `hc send` or
  `startReviewer`). The answer is keyed by thread id, so it shows on the card and not on a
  diff row.
- **The sidebar opens the queue** through the existing `better-changes.open-thread` handoff,
  with `queue: true` when no thread is named.

## Dependency graph
```
review-queue.js (rule + tests) ← readThreads (author ids, bot flag) + me
   ├── footer counts (threads.js)  ── sidebar chip (mr-inbox.js / inbox.js)
   └── queue panel + card (threads.js)
          ├── stepping cn/cN, whole-file fallback, sidebar → queue (threads.js, vim.js, inbox.js)
          ├── Reply / Resolve / Fix with agent buttons + keys (threads.js, vim.js)
          └── Ask AI keyed by thread (reviewer.js, threads.js)
```

## Task list
### Phase 1: the rule and the counts
- [x] Task 1: `reviewQueue` and the note data it needs
- [x] Task 2: MR-wide counts in the footer and the sidebar chip

### Checkpoint A
- [ ] `node --test git/` passes
- [ ] On !9271 the footer says `3 open` on every file, the same as the sidebar chip

### Phase 2: the queue
- [x] Task 3: queue panel and card
- [x] Task 4: moving through the queue

### Checkpoint B
- [ ] Clicking "3 threads" in the sidebar lands on 1 / 3 at `resolvers/dashboard.ex:13`, and
      `cn` walks to 3 / 3
- [ ] No bot plain comment and no `****` anywhere

### Phase 3: the actions
- [x] Task 5: Reply, Resolve, Fix with agent
- [x] Task 6: Ask AI on a thread
- [ ] Task 7: help, version, spec closed out

### Phase 4: the sidebar inbox tree
- [x] Task 8: tree layout for Mine (repo → MR row → queue items), compact status line
- [x] Task 9: Reviews tab in the same tree; clicking an item opens it in the queue

### Checkpoint D
- [ ] !9271 shows its 3 threads as child rows, and a click lands on that card in Better Changes

### Phase 5: the agent's result on the card
- [x] Task 10: `bin/thread-note` and its parsing (tested), the instruction in Fix with agent's message
- [x] Task 11: activity log in shared state; result and Reply & resolve on the card; ✈/✓ on the tree row

### Checkpoint E
- [ ] An agent's `thread-note --fixed` shows on the !9271 card, and Reply & resolve posts and resolves

### Checkpoint C
- [ ] All 9 of the spec's success criteria checked live on !9271 (resolving and replying on a
      throwaway thread, or reopened afterwards)
- [ ] Review with the person before committing

## Risks and mitigations
| Risk | Impact | Mitigation |
|---|---|---|
| herdr's runtime can't import across mods (`better-sidebar` → `../../better-changes/git/review-queue.js`); no mod does this today | Med: the rule would live in two places | Spike it first in Task 2. If it fails, better-sidebar gets a copy with a comment naming the source, and the test runs both copies |
| A reply or resolve on !9271 changes real review state | Med | Check on a thread I reopen right after, or on a scratch MR |
| `cn` currently drives threads, findings and comments, and the queue mode changes it | Low | Queue mode only while the panel is open (decision 2); closing it restores today's behaviour |
| Uncommitted changes already in `better-changes` (`git/reads.js`, `git/repository.js`, `main.js`, `mod.json`) | Med: mixing them into this change | Leave them out of these commits; touch `mod.json` only for the version, staged by hunk |
| An Ask AI answer keyed by thread clashes with answers keyed by row | Low | A separate `threadAnswers` list in the review state |

## Open questions
None. Decisions 1 and 2 are in the spec.
