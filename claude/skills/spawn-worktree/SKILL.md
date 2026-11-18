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
   - `--model` and `--effort` for the planning agent: fable/high for a hard feature or an
     investigation, opus/high or opus/medium for a simpler feature, sonnet/medium for a fix
     of known shape, haiku/low for a small spelled-out change. Implementation moves to
     sonnet at handoff.

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
   - Work through the agent-skills plugin (entry using-agent-skills). Before building,
     run /grilling on the task with the person, and start once you both read it the
     same way. When the task has no ticket or spec, or is still vague, run
     agent-skills:interview-me first until the person confirms the statement of intent. When a phase
     ends, offer the next ones with a recommendation and wait for the person's pick.
   - Before reporting finished work, commit, and rebase onto <base> when it has moved
     and this branch was never pushed.
   - End each turn with a report whose first line says what is true now." \
     '{name:$n, folder:$f, task:$t,
       argv:["env","DISABLE_AUTO_COMPACT=1","claude","--name",$n,"--model","<model>","--effort","<effort>","--permission-mode","auto"]}')"
   ```

   On failure, say the worktree is at its path with no agent, and stop.
6. **Report** in one line: "`<branch>` is on it", then go back to this session's thread.
