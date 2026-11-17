---
name: drop-worktree
description: Drop a worktree completely - its folder, its branch, and the Herdr space with its agent. Use when the person asks to drop, remove or clean up a worktree or branch.
---

`<branch>` is the one the person names, else `git branch --show-current`.
`main=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")` is the main
checkout; `<path>` is the worktree holding `<branch>` in `git worktree list --porcelain`.
Run every git command with `-C "$main"`, since `<path>` disappears. Each step that stops
says why and leaves everything where it is.

1. **Safe.** Stop and ask when either check fails:
   - `git -C <path> status --porcelain` prints nothing;
   - the branch's commits are not lost: `<branch>` is contained in a branch on origin
     (`git branch -r --contains <branch>` lists one).
2. **Find the space.** In `herdr-app ls`, the space whose folder is `<path>`. Note
   whether it is the one this session runs in (`$HC_TERMINAL_ID` among its terminals).
3. **Close another session's space first**, so no shell keeps the folder busy:
   `herdr-app do space.close '{"id":"<id>","confirmed":true}'`.
4. **Remove the worktree.** `git -C "$main" worktree remove <path>`.
5. **Delete the branch.** `git -C "$main" branch -d <branch>`. When git refuses because
   the branch is not merged locally, but step 1 found it on origin, use `-D`.
6. **Report** what went, in one line.
7. **Close this session's own space last**, when step 2 found it, since this ends the
   session.
