---
name: spawn-worktree
description: Start a separate change in its own git worktree and branch, with a Claude agent working it in a new Herdr space. Use when the person asks to spawn, start or hand off a change to a new worktree or agent.
---

`main=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")` is the main
checkout. Worktrees live where Herdr makes its own, so they show in its worktree lists:
`wt="$HOME/.herdr/worktrees/$(basename "$main")/<branch with / as ->"`. Each step that
stops says why and leaves everything where it is.

1. **Settle the launch** in one question that ends the turn, naming all of them:
   - the branch: lowercase, digits, `-` and `/`, at most 32 characters; a prefix for the
     kind (`fix/`, `feat/`, `chore/`, `docs/`, `research/`, `investigation/`), unless the
     repo's own rules name another;
   - the base: the branch `$main` has checked out, unless the repo's rules name another;
   - `--model` and `--effort`: sonnet/medium for a fix of known shape, opus/medium for a
     feature, opus/xhigh for an investigation, haiku/low for a small spelled-out change.

   "Spawn `fix/login-500` from `staging` on sonnet, medium?" The person may change any.
2. **Free.** `git -C "$main" rev-parse --verify --quiet refs/heads/<branch>` finds
   nothing and `$wt` does not exist.
3. **Create.** `git -C "$main" worktree add -q -b <branch> "$wt" <base>`.
   Then prime it: `~/.claude/skills/spawn-worktree/prime.sh "$main" "$wt"` clones the main
   checkout's `deps`, `_build` and `node_modules` copy-on-write and links its `.envrc`, so
   the worktree builds warm.
4. **Trust.** When `jq -e --arg f "$wt" '.projects[$f].hasTrustDialogAccepted' ~/.claude.json`
   fails, the agent opens on Claude's trust prompt: say so in the report.
5. **Start the agent.** Write the task: the person's own words, what this conversation
   already said about the change, the files and links involved, and how many commits.
   Leave open questions open. Then:

   ```sh
   herdr-app do space.new "$(jq -n --arg n <branch> --arg f "$wt" \
     --arg t "Your branch <branch> was cut from <base>.

   Your task:

   <task>

   How you work:
   - Stay in this worktree, commit only on <branch>, and move no other branch. Never
     git stash: its stack is shared with every worktree.
   - Never push, open a merge request or post anywhere unless the person says so.
   - Before building, run /grilling on the task with the person, and start once you
     both read it the same way.
   - Before reporting finished work, commit, and rebase onto <base> when it has moved
     and this branch was never pushed.
   - End each turn with a report whose first line says what is true now." \
     '{name:$n, folder:$f, task:$t,
       argv:["claude","--name",$n,"--model","<model>","--effort","<effort>","--permission-mode","acceptEdits"]}')"
   ```

   On failure, say the worktree is at its path with no agent, and stop.
6. **Report** in one line: "`<branch>` is on it", then go back to this session's thread.
