#!/usr/bin/env bash
# Test for smart_pane_nav.sh up/down with a fake herdr. Run: /bin/bash smart_pane_nav_test.sh
# Uses /bin/bash on purpose: herdr runs the script under macOS bash 3.2.
here=$(cd "$(dirname "$0")" && pwd)
bin=$(mktemp -d); trap 'rm -rf "$bin"' EXIT
cat > "$bin/herdr" <<'F'
#!/bin/bash
case "$1 $2" in
  "pane focus") echo '{"result":{"focus":{"changed":false}}}' ;;
  "pane current") echo "{\"result\":{\"pane\":{\"workspace_id\":\"$FAKE_CURRENT\"}}}" ;;
  "workspace list") cat <<J
{"result":{"workspaces":[
 {"workspace_id":"A","number":1,"worktree":{"repo_key":"a","is_linked_worktree":false}},
 {"workspace_id":"A1","number":2,"worktree":{"repo_key":"a","is_linked_worktree":true}},
 {"workspace_id":"B","number":3,"worktree":{"repo_key":"b","is_linked_worktree":false}},
 {"workspace_id":"B1","number":4,"worktree":{"repo_key":"b","is_linked_worktree":true}},
 {"workspace_id":"C","number":5,"worktree":{"repo_key":"c","is_linked_worktree":false}}]}}
J
  ;;
  "workspace focus") echo "$3" > "$FAKE_OUT" ;;
esac
F
chmod +x "$bin/herdr"
fail=0
check() { # current dir expected
  FAKE_CURRENT=$1 FAKE_OUT="$bin/out" PATH="$bin:$PATH" /bin/bash "$here/smart_pane_nav.sh" "$2"
  got=$(cat "$bin/out"); rm -f "$bin/out"
  [ "$got" = "$3" ] || { echo "FAIL $1 $2: got '$got' want '$3'"; fail=1; }
}
check B  up   A    # skips A1 (mouse) going up from B
check B  down C    # skips B1
check A  up   C    # wraps
check C  down A
check A1 up   A    # mouse -> own main
check B1 down B
exit $fail
