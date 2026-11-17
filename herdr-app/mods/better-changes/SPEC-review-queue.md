# Spec: review queue in Better Changes

## Objective

As the MR's author, I work through the review feedback on my branch (mostly CodeRabbit's) one
thread at a time, and settle each one by fixing it with the agent, replying, asking AI or
resolving it. Today the thread panel is per file. It shows MR-level bot summaries at full length
on every file, names the bot `****`, and its footer counts only the open file, so it reads
"0 open" while the sidebar says "3 threads".

The **queue** is the MR's open items in one ordered list, with the one being worked on shown as
a **card**.

### What the queue holds
| Item | Author | In queue |
|---|---|---|
| Resolvable thread, unresolved | anyone | yes |
| Resolvable thread, resolved | anyone | no |
| Plain comment (not resolvable) | bot (`isBot`, as in better-sidebar's mr-inbox) | no |
| Plain comment | person, not me | yes, until I reply or dismiss it |

Order: items **waiting on me** (the last note isn't mine) first, oldest first. Items **waiting on
them** (I wrote last) go to the bottom, labelled so.

### The card
- Where it is (`path:line`, or "On the merge request"), the state (Open / waiting on them) and
  the position (`2 / 3`).
- The first note (the finding), clamped to about 8 lines, with "Show all".
- The latest reply in full, when there is one. Replies in between fold into "n earlier replies".
- The author's name, or `@username` when GitLab masks the name as `****`.
- Bodies without the HTML comments bots use for bookkeeping (`visibleMarkdown`, as today).
- Four actions, as real buttons with keys:
  - **Reply** `r`: a box under the card that posts to the thread on GitLab (⌘↩ sends).
  - **Resolve** `x`: resolves on GitLab, and the queue moves on to the next item.
  - **Ask AI** `a`: the thread goes as a question to the reviewer Claude (`views/reviewer.js`),
    or starts one if none is running. It reads only and changes nothing. Its answer shows on the
    card, under the notes.
  - **Fix with agent** `F`: the thread joins the review comments for the working agent, as
    `threadToAgent` does today.

### Moving through it
- Clicking "n threads" in the sidebar opens the queue on that MR's first item.
- `cn` / `cN` step to the next / previous queue item. Each step opens the item's file and puts
  the diff cursor on its line.
- A thread on a line the changes-only diff doesn't show switches the diff to the whole file at
  that line. A thread on a file no longer in the diff (outdated) or on no file shows its card
  with "not in this diff".
- `t` shows or hides the queue panel. It replaces the per-file "Every thread on <file>" list.
- The footer reads `Threads 2 open · 1 waiting on them` across the whole MR, the same counts as
  the sidebar.

### The sidebar inbox as a tree (better-sidebar)
The Mine and Reviews tabs show repo → MR → items:
- "Nothing waiting on you · checked 2m ago" is one small dim line.
- An MR is one compact row: its title, then `!iid` and small icons for pipeline, approval and
  thread count. A failed pipeline or a conflict turns its icon red; neither is a row of its own.
- Mine: the MR's queue items (the same `reviewQueue`) as `● path:line`, with "waiting on them"
  dimmed. A click opens the item in the Better Changes queue.
- Reviews: "review · not approved at head" first, then the threads I'm in where someone answered
  me.
- An MR with items starts expanded and one without starts collapsed; each can be toggled.
- Out of scope: the Spaces and Agents tabs, notifications, and the poll interval.

### The agent's result comes back to the card
- Fix with agent's message carries the thread id and one instruction: when done, run
  `bin/thread-note <file> <id> --fixed <commit>` (or `--already-fixed <commit>`), or
  `--not-fixed "<reason>"`. The file is `.git/better-changes-threads.jsonl` in the repo.
- Better Changes polls the file and shows the result on the card: "Fixed in `<commit>`" with
  **Reply & resolve** (`x`), which posts "Fixed in `<commit>`." and resolves the thread; or the
  one-line reason, with no button.
- A persisted per-thread log in shared state `review-queue.activity` (sent, result, asked)
  feeds the card's line and the tree row's icon: ✈ while sent, ✓ when the result is in.
- The agent never posts on GitLab. Resolving stays my click.

## Tech stack
herdr-app mod in JavaScript (ES modules) on `gpui-kit` / `gpui-base` / `herdr`. GitLab through
`glab api`. The reviewer is `claude` in a split pane (`views/reviewer.js`). No build step and no
dependencies.

## Commands
- Reload: the mod is symlinked into `~/.config/herdr-app/mods/better-changes`, and herdr picks
  up a saved file on reload.
- Unit tests: `node --test herdr-app/mods/better-changes/git/` (Node's built-in runner).
- Live check: !9271 on platform-backend (3 open CodeRabbit threads, 4 bot plain comments).

## Project structure
- `git/merge-request.js`: `readThreads` (adds each note's author id and bot flag) and a pure
  `reviewQueue(threads, me)` holding the table and order above. Its test sits next to it,
  `git/merge-request.test.js`.
- `views/threads.js`: the queue panel, the card, the footer, and stepping through the queue.
- `views/reviewer.js`: Ask AI for a thread, reusing `sendQuestion`'s path, with the answer keyed
  by thread id.
- `views/vim.js`, `views/help.js`: the keys `x` and `F` on the card, `a` / `r` when the card is
  the target, and the help text.
- `mod.json`: version bump to 2.6.0.

## Code style
Matches the files around it: methods on `threadMethods`, gpui builder chains, short comments
that say why, `TextButton` / `BarButton` / `Icon` from `views/ui.js`.

```js
const waitingOnMe = (item, me) => item.notes[item.notes.length - 1].authorId !== me;
```

## Testing strategy
- `reviewQueue` is test-first with `node --test`: the table's rows, the order, the masked-name
  fallback, and threads with several replies.
- Views have no harness, so they're checked live in herdr on !9271. The before/after
  screenshots go to the person.

## Boundaries
- Always: read GitLab's state after every write (`changeThread` already does), and keep the
  sidebar and Better Changes counting the same items.
- Ask first: changes to better-sidebar beyond the counts and the inbox tree, new keys that clash with the vim keys,
  any dependency.
- Never: write to GitLab beyond a reply or a resolve, let Ask AI edit code, or touch the
  uncommitted changes already in the dotfiles worktree (`git/reads.js`, `git/repository.js`,
  `main.js`, `mod.json`) beyond the version bump.

## Success criteria
1. On !9271, with `src/.../dashboard.ex` open, the footer says `3 open`, the same as the sidebar.
2. The queue lists exactly the 3 open CodeRabbit threads. "Actionable comments posted",
   "Prompt to fix all issues" and the other bot plain comments don't appear.
3. Clicking "3 threads" in the sidebar lands on item 1 / 3 with the cursor on
   `resolvers/dashboard.ex:13`. `cn` goes to `index.tsx:44`, then `index.test.tsx:181`.
4. No card shows `****` as the author.
5. Resolve (`x`) on item 1 resolves it on GitLab, and the queue shows 1 / 2 on the next item.
6. A reply (`r`, ⌘↩) posts to GitLab. The thread moves to the bottom, marked waiting on them,
   and the footer counts it under "waiting on them".
7. Ask AI (`a`) shows the reviewer's answer on the card and leaves `git status` unchanged.
8. Fix with agent (`F`) adds the thread to the review comments, the same way "→ agent" does
   today.
9. `node --test` passes.

## Decisions
5. Fix with agent sends the one thread straight to the branch's agent, or starts one; the review
   comments list is left alone, and the button reads "Sent to agent".
6. `x` on a plain comment dismisses it locally (shared `review-queue.dismissed`) until a newer
   note; both mods filter the queue with it.
7. Restart Herdr: a footer button in better-sidebar and ⌘§ (`better-sidebar.restart`). A
   detached shell reopens the app once it has quit.
3. The card's buttons are pills with an icon, a label and a key hint. Fix with agent is filled
   in the accent colour, Resolve has a green tint, and Ask and Reply are outlined.
4. ⇧⌘↩ is unbound from `pane.zoom` in `~/.config/herdr-app/keys.json`, so the comment box's
   "ask Claude" gets it.
1. Better-sidebar's chip uses the same split as the footer (`2 threads · 1 waiting on them`),
   with one small edit to `git/mr-inbox.js` / `views/inbox.js`.
2. While the queue panel is open, `cn` / `cN` step through the queue only. With it closed they
   step through threads, findings and my review comments, as today.
