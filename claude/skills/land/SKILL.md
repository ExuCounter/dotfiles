---
name: land
description: Land this worktree's branch on a branch you pick as a fast-forward, push it when you say, then remove the worktree.
disable-model-invocation: true
---

Run from the worktree whose branch lands; `<branch>` is `git branch --show-current`, and
`main=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")` is the main
checkout. Each step that stops says why, and leaves everything where it is.

1. **Clean.** `git status --porcelain` prints nothing, and this is a worktree, not `$main`.
2. **Ask where it lands**: end the turn on one plain question, no lettered options,
   naming the branch this one was cut from (from the session's first message) as the
   recommendation, and the branch `$main` has checked out
   (`git -C "$main" branch --show-current`) or the default branch
   (`git symbolic-ref --short refs/remotes/origin/HEAD`, less `origin/`) where they
   differ. The person answers with any local branch; that is `<target>`.
3. **Put this branch's own commits on `<target>`**:
   `git rebase --onto <target> "$(git merge-base HEAD <cut-from>)"`, with `<cut-from>` the
   branch it was cut from, or `<target>` when the first message names none. Only the
   commits made here move, whatever `<target>` holds. A conflict you cannot settle:
   `git rebase --abort` and ask.
4. **Checks**, when step 3 moved anything: the ones the repo's CLAUDE.md names, else its test
   suite. Red stops here.
5. **Fast-forward `<target>`** to `<branch>`. `git worktree list --porcelain` shows where
   `<target>` is checked out: there, that worktree is clean and
   `git -C <it> merge --ff-only <branch>`; checked out nowhere, `git fetch . <branch>:<target>`.
   A refusal stops here.
6. **Ask to push**: end the turn on "Push `<target>` to origin now?". On yes,
   `git push origin <target>`. A rejected push stops here; it is never forced.
7. **Report** what landed in one line, `<branch>` → `<target>`, its commits and whether it
   was pushed. Then, as the last call, since it ends this session, remove the worktree:
   `herdr worktree remove --workspace "$HERDR_WORKSPACE_ID"` inside herdr, else
   `git -C "$main" worktree remove "$PWD"`. The branch stays.
