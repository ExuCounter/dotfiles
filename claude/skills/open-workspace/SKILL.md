---
name: open-workspace
description: "Switch to an existing herdr workspace and start Claude in it if not already running. Use when the user asks to open, switch to, jump to, or go to a workspace by name. Requires HERDR_ENV=1."
---

# open-workspace

Focus an existing herdr workspace and make sure Claude is running there. Does not create anything — for creating a new worktree/workspace use `spawn-worktree`.

## Preconditions

```bash
test "${HERDR_ENV:-}" = 1
command -v herdr
```

If any check fails, say what's missing and stop.

## Identify the target

Ask the user which workspace, unless they've named one. Show the current list to help them choose:

```bash
herdr workspace list | jq '.result.workspaces[] | {workspace_id, label}'
```

Match by `label` (case-insensitive substring is fine). If multiple match ambiguously, ask which one.

If nothing matches the requested name, check if there's a git worktree that fits and hasn't been opened as a workspace yet:

```bash
herdr worktree list | jq '.result.worktrees[] | select(.open_workspace_id == null)'
```

If found, open it:

```bash
herdr worktree open --workspace <source-workspace-id> --path <worktree-path> --focus
```

Otherwise report "no workspace matched" and stop — do not create one silently.

## Focus the workspace

```bash
herdr workspace focus <workspace-id>
```

## Create a fresh tab with Claude

Always create a new tab in the workspace and start a Claude session in it — this skill's job is to give the user a new session, not to reuse an old one.

```bash
herdr tab create --workspace <workspace-id> --focus
```

Parse `.result.root_pane.pane_id` from the response. Then wait for the shell to initialise and start Claude:

```bash
sleep 2
herdr agent start <unique-name> --kind claude --pane <root-pane-id>
```

Pick `<unique-name>` from the workspace label plus a short suffix if needed (agent names must be unique among live agents). If `agent start` errors with "pane not at prompt", sleep 2 more seconds and retry once.

## Report back

One line: which workspace you switched to and that a fresh Claude session is starting.
