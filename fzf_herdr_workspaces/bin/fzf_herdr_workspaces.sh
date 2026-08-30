#!/usr/bin/env bash
# FZF workspace + layout picker for herdr (herdr counterpart to
# fzf_tmux_sessions). Lists running workspaces and available layout scripts,
# then focuses or launches on ENTER.
#
# Bound in herdr.toml as a `type = "popup"` command on prefix+f.

set -euo pipefail

LAYOUTS_DIR="${HERDR_LAYOUTS_DIR:-$HOME/.config/herdr_layouts}"

# Build the list: running workspaces first, then available layouts.
# Prefix each row with a category tag so we can dispatch on ENTER.
build_entries() {
  herdr workspace list 2>/dev/null \
    | jq -r '.result.workspaces[]? | "ws\t\(.workspace_id)\t\(.label)"' \
    | awk -F'\t' '{ printf "  [ws]  %-30s  %s\n", $3, $2 }'

  if [ -d "$LAYOUTS_DIR" ]; then
    # Skip lib.sh; only user-facing layout scripts.
    find -L "$LAYOUTS_DIR" -maxdepth 1 -name '*.sh' ! -name 'lib.sh' -type f \
      | sort \
      | while read -r f; do
          name=$(basename "$f" .sh)
          printf "  [new] %-30s  %s\n" "$name" "$f"
        done
  fi
}

selection=$(build_entries | fzf \
  --prompt='herdr> ' \
  --header='ENTER: focus workspace / launch layout   ESC: cancel' \
  --height=100% \
  --no-sort \
  --ansi) || exit 0

[ -z "$selection" ] && exit 0

kind=$(printf '%s' "$selection" | awk '{print $1}')
target=$(printf '%s' "$selection" | awk '{print $NF}')

case "$kind" in
  '[ws]')
    herdr workspace focus "$target" >/dev/null
    ;;
  '[new]')
    bash "$target"
    ;;
esac
