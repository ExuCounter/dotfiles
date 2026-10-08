#!/usr/bin/env bash
# Whiska: pick what is waiting on you and jump to its main session.
# Lists everything waiting, oldest first, with the full question in the
# preview. Prototype, bound in herdr.toml.
#
# Built for speed: fzf opens at once and the rows stream in behind it, and the
# jump asks herdr directly (~30ms) instead of starting whiska again (~250ms).

set -uo pipefail

# herdr runs popups in a bare login shell that never reads ~/.zshrc, so
# whiska, its Erlang runtime and fzf are not on PATH unless added here.
PATH="$HOME/.local/bin:$HOME/.asdf/shims:/opt/homebrew/bin:$PATH"

# Hidden fields 1-3 (id, checkout, repo) drive the preview and the jump;
# field 4 is the visible row.
rows() {
  whiska waiting --json 2>/dev/null | jq -r '.[] | [
    .id, .main_checkout, .repo,
    ("#\(.id)  \(.repo)  \(.branch)  · \(
      if .waits then .waits elif .kind == "done" then "finished" else "waiting" end
    )  · \(.pointer // "" | gsub("[*`\n]"; "") | .[0:70])")
  ] | @tsv'
}

selection=$(rows | fzf --reverse --no-sort \
  --delimiter '\t' --with-nth 4 \
  --header 'enter: jump to its main session' \
  --bind 'load:transform-header:[ "$FZF_TOTAL_COUNT" -eq 0 ] && echo "Nothing is waiting on you. esc to close" || echo "enter: jump to its main session"' \
  --preview 'cd {2} && whiska show {1}' --preview-window 'down,60%,wrap' \
  | cut -f2)

[ -z "$selection" ] && exit 0

# The repo's main session is the workspace open on its main checkout itself,
# not on one of its worktrees.
workspace=$(herdr workspace list | jq -r --arg checkout "$selection" '
  .result.workspaces[]
  | select(.worktree.checkout_path == $checkout and (.worktree.is_linked_worktree | not))
  | .workspace_id' | head -1)

if [ -n "$workspace" ]; then
  herdr workspace focus "$workspace" >/dev/null
else
  whiska jump "$(basename "$selection")"
fi
