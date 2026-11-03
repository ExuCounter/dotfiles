---
name: cold-review
description: Review a finished change with a fresh reviewer, plus a security reviewer when it applies, before reporting it done. Use only when a task, a CLAUDE.md or the person asks for a cold review or a security review.
---

A cold review is one by a reviewer that never saw this session. A reviewer briefed from the builder's plan judges the diff against the builder's intent rather than against what the person wanted, so it gets the diff and what was asked for, and nothing of how you chose to build.

## Steps

1. **Read the change back** against the spec, or a bug's research document, and the repo's recorded decisions (ADRs, CLAUDE.md). Fix each gap now.
2. **Send the cold reviewer**, a fresh subagent, given:
   - the diff from the branch's base: `whiska base` names it in a Whiska worktree, else the merge-base with the default branch;
   - the spec or research document;
   - the repo's decisions as they stood at the base.

   The build plan and this session's reasoning stay out of its brief. It reports findings by `file:line` and edits nothing.
3. **Add a security reviewer**, briefed the same way, when the change touches input, permissions, hooks, prompts or secrets.
4. **Wait for every reviewer's report**, then disprove or fix each finding. Done when each finding is disproved or fixed.
5. **Second round** over what changed, if anything did. After two rounds, what is still open goes to the person.

A finding left unfixed goes to the person as a question before any finished report: a finished branch can land with no one reading its report.
