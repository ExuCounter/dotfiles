---
name: pr
description: Push this worktree's branch and open its GitLab merge request on a target you pick, or push to the one already open.
disable-model-invocation: true
---

`<branch>` is `git branch --show-current`. What the repo's CLAUDE.md says about merge
requests (a template, labels, reviewers, draft or not) wins over the defaults below.

1. **Clean.** `git status --porcelain` prints nothing; else stop and name what is
   uncommitted.
2. **One already open**: `glab mr list --source-branch <branch>` lists it. Push
   (step 5) and report its link. Done.
3. **Ask the target**: end the turn on one plain question, no lettered options, naming
   the branch this one was cut from (from the session's first message) as the
   recommendation, and the default branch
   (`git symbolic-ref --short refs/remotes/origin/HEAD`, less `origin/`) where it differs.
   The person answers with any branch on origin; that is `<target>`.
4. **Another target than the one it was cut from**: `git fetch origin <target>`, then
   `git rebase --onto origin/<target> "$(git merge-base HEAD <cut-from>)"`, so only the
   commits made here go up, and run the repo's checks again. A conflict you cannot settle:
   `git rebase --abort` and ask.
5. **Push**: `git push -u origin HEAD`. Rejected after a rebase: ask before
   `--force-with-lease`; it is never `--force`.
6. **Open it**: `glab mr create --source-branch <branch> --target-branch <target> --title
   "<what it does, in a few words>" --description "<what changed and why, and what was
   run>" --yes`. Report its link; the owl shows it in the sidebar within seconds.
