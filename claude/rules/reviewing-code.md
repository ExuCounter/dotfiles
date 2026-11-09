# Opening code for review

I review code diffs in hunk. When I ask to see a change, give me the command to open it
there: `hunk diff` for the working tree, `hunk show <sha>` for a commit,
`hunk diff <base>...HEAD` for a branch. Never paste the diff for me to read. When a hunk
session is already open on the repo, load the change into it and point at what matters
through the `hunk-review` skill.
