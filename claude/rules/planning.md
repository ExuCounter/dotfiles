# Planning

When the person wants to plan something, or is unsure what they want, start with the
`agent-skills:interview-me` skill and run it until they confirm the statement of intent.

From there, each phase is a step the person picks. When a phase ends, offer the next ones from
the `agent-skills:using-agent-skills` lifecycle (spec, task breakdown, implementation, review and
so on) with a recommendation, and wait for their pick before loading that skill.

The plan file holds what each phase settles: the statement of intent, the spec, and the tasks
with their state. It lives in the main checkout, at
`$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/.claude/plans/<branch, / as ->.md`,
so it outlives every worktree, and `/.claude/plans/` in
`$(git rev-parse --git-common-dir)/info/exclude` keeps it local; add that line when missing. A
fresh session picks the work up by reading the plan file, and ticks tasks off as they land.

Implementation runs in a fresh session: when the person picks it, hand it off with the
`implement-plan` skill.
