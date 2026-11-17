# Worktrees

A change the person asks for that is separate from this session's thread (another bug,
another feature, a question to research) goes to a new worktree and agent through the
`spawn-worktree` skill, unless the person says to do it here. Dropping a worktree, or a
branch that has one, goes through `drop-worktree`, so its space and agent go with it.
