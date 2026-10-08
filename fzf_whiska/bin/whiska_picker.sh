#!/usr/bin/env bash
# Whiska: every project's main session in fzf, the ones waiting on you first;
# enter jumps there. The list is `whiska jump --list`, one tab-separated line
# per project: repo, main checkout, waiting count, oldest wait in seconds, summary.
#
# The jump asks herdr directly (~30ms) and falls back to `whiska jump` (~250ms)
# when no herdr workspace sits on the main checkout.

set -uo pipefail

# herdr runs popups in a bare login shell that never reads ~/.zshrc.
PATH="$PATH:$HOME/.local/bin:$HOME/.asdf/shims:/opt/homebrew/bin"

header='enter: jump to its main session · esc: close'
if ! list=$(whiska jump --list 2>&1); then
  header="whiska jump --list failed: $(head -1 <<<"$list")"
  list=""
elif [ -z "$list" ]; then
  header='No project is recorded. esc to close'
fi

# Hidden fields 1-2 (repo, checkout) drive the preview and the jump; fields 3-4
# are the visible row, and typing matches field 3, the repo, alone.
rows() {
  [ -n "$list" ] && awk -F'\t' '
    function ago(s) {
      if (s < 60) return s "s"
      if (s < 3600) return int(s / 60) "m"
      if (s < 86400) return int(s / 3600) "h"
      return int(s / 86400) "d"
    }
    { line[NR] = $0; if (length($1) > w) w = length($1) }
    END {
      for (i = 1; i <= NR; i++) {
        split(line[i], f, "\t")
        what = f[3] > 0 ? f[3] " waiting · " ago(f[4]) " · " f[5] : f[5]
        printf "%s\t%s\t%-*s\t%s\n", f[1], f[2], w, f[1], what
      }
    }' <<<"$list"
}

pick=$(rows | fzf --reverse --no-sort \
  --delimiter '\t' --with-nth 3,4 --nth 1 \
  --header "$header" \
  --preview 'cd {2} && whiska questions' --preview-window 'down,50%,wrap')

[ -z "$pick" ] && exit 0
checkout=$(cut -f2 <<<"$pick")

# The popup closes on exit, so a reason not to jump stays on screen until a key.
hold() {
  printf '%s\npress any key to close' "$1"
  read -r -n 1
}

if [ "$(cut -f4 <<<"$pick")" = "no main session" ]; then
  hold "$(cut -f1 <<<"$pick") has no main session. Run \`whiska start\` in its main checkout's pane."
  exit 0
fi

workspace=$(herdr workspace list 2>/dev/null | jq -r --arg checkout "$checkout" '
  .result.workspaces[]?
  | select(.worktree.checkout_path == $checkout and (.worktree.is_linked_worktree | not))
  | .workspace_id' 2>/dev/null | head -1)

if [ -n "$workspace" ]; then
  herdr workspace focus "$workspace" >/dev/null
elif ! out=$(whiska jump "$checkout" 2>&1); then
  hold "$out"
fi
