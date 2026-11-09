#!/usr/bin/env bash
# Every Claude agent in fzf, the ones blocked on you first, then done, idle and
# working, each in workspace order. A row is the agent's workspace label, its
# status and its $whiska token; the preview is the agent's screen and enter
# focuses its pane.

set -uo pipefail

# herdr runs popups in a bare login shell that never reads ~/.zshrc.
PATH="$PATH:$HOME/.local/bin:/opt/homebrew/bin"

header='enter: focus the agent · esc: close'
list=""
if ! agents=$(herdr agent list 2>&1); then
  header="herdr agent list failed: $(head -1 <<<"$agents")"
else
  list=$(jq -r --argjson spaces "$(herdr workspace list)" '
    ($spaces.result.workspaces | map({key: .workspace_id, value: .}) | from_entries) as $ws
    | {blocked: 0, done: 1, idle: 2, working: 3} as $rank
    | [.result.agents | to_entries[] | select(.value.agent == "claude")
        | .value as $a | ($ws[$a.workspace_id] // {}) as $w
        | {key: [($rank[$a.agent_status] // 4), ($w.number // 1e9), .key],
           row: [$a.pane_id, ($w.label // $a.workspace_id), $a.agent_status,
                 ($w.tokens.whiska // "")]}]
    | sort_by(.key)[] | .row | @tsv' <<<"$agents")
  [ -z "$list" ] && header='No Claude agent is running. esc to close'
fi

# Hidden field 1 (pane id) drives the preview and the focus; the label is padded
# so the statuses line up, and typing matches the label alone.
rows() {
  [ -n "$list" ] && awk -F'\t' '
    { line[NR] = $0; if (length($2) > w) w = length($2) }
    END {
      for (i = 1; i <= NR; i++) {
        split(line[i], f, "\t")
        printf "%s\t%-*s\t%s\t%s\n", f[1], w, f[2], f[3], f[4]
      }
    }' <<<"$list"
}

pick=$(rows | fzf --reverse --no-sort \
  --delimiter '\t' --with-nth 2.. --nth 1 \
  --header "$header" \
  --preview 'herdr agent read {1}' --preview-window 'down,50%,wrap')

[ -z "$pick" ] && exit 0
herdr agent focus "$(cut -f1 <<<"$pick")" >/dev/null
