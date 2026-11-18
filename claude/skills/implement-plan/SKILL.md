---
name: implement-plan
description: Hand a plan file's open tasks to a fresh Sonnet implementer, in a Herdr tab, subagents or this session. Use when the person picks implementation of a planned change.
---

The implementer starts from the plan file alone, so the planning context stays behind.

1. **Pick the way** in one question that ends the turn, recommending one:
   - **Tab**: the person steers the implementation turn by turn.
   - **Subagents**: the person hands the plan off and comes back for the result.
   - **Here**: the change is smaller than the handoff.
2. **Hand off.**
   - **Tab.** In Herdr (`HC_TERMINAL_ID` is set), open it in this space and worktree:

     ```sh
     herdr-app do tab.new "$(jq -n --arg s "$(hc get "$HC_TERMINAL_ID" | jq -r '.labels["herdr.space"]')" \
       --arg f "$PWD" --arg t "Implement from the plan file <plan file>: read it first, do its open
     tasks one at a time, tick each off and commit it." \
       '{name:"implement", space:$s, folder:$f, task:$t,
         argv:["claude","--model","sonnet","--effort","medium","--permission-mode","auto"]}')"
     ```

     Outside Herdr, give the person `claude --model sonnet --effort medium --permission-mode auto`
     and that first message to paste.
   - **Subagents.** One Agent call per open task, in plan order, each on `model: "sonnet"` with a
     fresh type such as `general-purpose`. Its prompt is the plan file path, the task, and "tick
     it off and commit it". The next task starts once the last one's commit is in, since all of
     them share this worktree.
   - **Here.** Work the open tasks one at a time, ticking each off and committing it.
3. **Report.** Tab: done when `tab.new` returns its terminal; say the `implement` tab has it, and
   this session stops. Subagents and here: done when every task in the plan file is ticked off
   and committed; report each task's commit.
