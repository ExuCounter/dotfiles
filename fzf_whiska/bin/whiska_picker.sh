#!/usr/bin/env bash
# Whiska: every project's main session in fzf, the ones waiting on you first;
# enter jumps there. The list is `whiska jump --list`, one tab-separated line
# per project: repo, main checkout, waiting count, oldest wait in seconds, summary.
#
# The list and the preview are asked of the running owl over ~/.whiska/owl.sock
# (nc, a few ms) because every `whiska` call boots the Erlang VM (~300ms). When the
# owl does not answer, both fall back to the `whiska` command.
#
# The jump asks herdr directly (~30ms) and falls back to `whiska jump` (~250ms)
# when no herdr workspace sits on the main checkout.

set -uo pipefail

# herdr runs popups in a bare login shell that never reads ~/.zshrc.
PATH="$PATH:$HOME/.local/bin:$HOME/.asdf/shims:/opt/homebrew/bin"

sock="${WHISKA_HOME:-$HOME/.whiska}/owl.sock"

# One request line to the owl; prints its reply, fails when the owl is not there.
owl() {
  [ -S "$sock" ] && printf '%s\n' "$1" | nc -w 2 -U "$sock" 2>/dev/null
}

# The preview pane, run by fzf as `whiska_picker.sh --preview <main checkout>`.
if [ "${1:-}" = --preview ]; then
  owl "questions $2" | jq -er '.questions' 2>/dev/null && exit 0
  cd "$2" && exec whiska questions
fi

header='enter: jump to its main session · esc: close'
list=""
# The owl's `jump` reply carries the same rows as `whiska jump --list`. Anything
# else — no owl, an old owl, an error reply — takes the command.
if reply=$(owl jump) && jq -e '.whiskas' >/dev/null 2>&1 <<<"$reply"; then
  list=$(jq -r '.whiskas[] | "\(.repo)\t\(.main_checkout)\t\(.waiting)\t\(.oldest_wait_seconds // "-")\t\(.summary)"' <<<"$reply")
  [ -z "$list" ] && header='No project is recorded. esc to close'
elif ! list=$(whiska jump --list 2>&1); then
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
  --preview "$(printf %q "$0") --preview {2}" --preview-window 'down,50%,wrap')

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
