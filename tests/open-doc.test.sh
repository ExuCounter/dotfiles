# The hunk-docs herdr plugin's action, run as herdr runs it on a Ctrl+click: the
# link and the clicked pane and workspace in its env, against a mock herdr that
# logs each call's arguments one per line and answers `tab create` with a new
# pane, and a mock hunk on a PATH that holds nothing else of the machine's.

PLUGIN="$REPO_ROOT/herdr_plugins/hunk-docs"
OPEN="$PLUGIN/open-doc.sh"

setup_doc_sandbox() {
  setup_sandbox
  mkdir -p "$SANDBOX/tools"
  ln -s "$(command -v jq)" "$SANDBOX/tools/jq"
  export PATH="$MOCK_BIN:$SANDBOX/tools:/usr/bin:/bin"
  unset XDG_CACHE_HOME MOCK_TAB_FAIL MOCK_TAB_WARN MOCK_TAB_NOPANE
  export MOCK_HUNK_ENV="$SANDBOX/hunk-env"
  export HERDR_PANE_ID=w1:p2 HERDR_WORKSPACE_ID=w1

  cat > "$MOCK_BIN/herdr" <<'MOCK'
#!/usr/bin/env bash
{ printf '%s\n' "$@"; echo '--'; } >> "$MOCK_HERDR_LOG"
case "$1 $2" in
  "tab create")
    [ -n "${MOCK_TAB_FAIL:-}" ] && { echo '{"error":{"code":"workspace_not_found"}}' >&2; exit 1; }
    [ -n "${MOCK_TAB_WARN:-}" ] && echo 'warning: config reloaded' >&2
    [ -n "${MOCK_TAB_NOPANE:-}" ] && { echo '{"id":"1","result":{"type":"tab_created"}}'; exit 0; }
    echo '{"id":"1","result":{"type":"tab_created","root_pane":{"pane_id":"w1:p9"}}}' ;;
esac
exit 0
MOCK
  # Prints the arguments it was started with, one per line, and records the
  # env hunk-send reads.
  cat > "$MOCK_BIN/hunk" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@"
printf '%s\n' "${HUNK_SEND_PANE-unset}" "${HUNK_SEND_DOC-unset}" > "$MOCK_HUNK_ENV"
MOCK
  chmod +x "$MOCK_BIN/herdr" "$MOCK_BIN/hunk"

  DOCS="$(cd "$SANDBOX" && pwd -P)/docs"
  mkdir -p "$DOCS"
  echo '# Spec' > "$DOCS/spec.md"
}

click() { HERDR_PLUGIN_CLICKED_URL="$1" bash "$OPEN"; }
# The arguments of the herdr call that starts with $1 $2, one per line.
herdr_call() { awk -v a="$1" -v b="$2" '
  /^--$/ { if (hit) exit; n = 0; next }
  { n++; if (n == 1) first = $0; if (n == 2 && first == a && $0 == b) { hit = 1; print first } if (hit) print }
' "$MOCK_HERDR_LOG"; }
# What the doc tab runs, run here with `exec` dropped.
tab_runs() {
  local line
  line="$(herdr_call pane run | sed -n 4p)"
  [ -n "$line" ] && (cd "$SANDBOX" && bash -c "${line# exec }")
}
notified() { herdr_call notification show | tr '\n' ' '; }

it "a Ctrl+clicked .md opens hunk on it in a new tab"
setup_doc_sandbox
click "file://$DOCS/spec.md" || fail "exited non-zero"
empty="$HOME/.cache/hunk-docs/empty"
assert_equals "$(herdr_call tab create)" "tab
create
--workspace
w1
--label
doc:spec.md
--cwd
$HOME
--focus" "tab create" &&
  assert_equals "$(herdr_call pane run | sed -n 3p)" "w1:p9" "the pane run in" &&
  assert_equals "$(herdr_call pane run | sed -n 4p | cut -c1-6)" " exec " "the start of the tab's command, kept out of zsh's history" &&
  assert_equals "$(tab_runs)" "diff
--files
$empty
$DOCS/spec.md
--watch
--no-sidebar
--mode
unified" "hunk's arguments" &&
  assert_equals "$(cat "$MOCK_HUNK_ENV")" "w1:p2
$DOCS/spec.md" "hunk's HUNK_SEND_PANE and HUNK_SEND_DOC" &&
  assert_file_exists "$empty" && assert_equals "$(wc -c < "$empty" | tr -d ' ')" 0 "the empty file's size" && pass
teardown_sandbox

it "a percent-encoded name on localhost opens the decoded file, quoted for the tab's shell"
setup_doc_sandbox
mkdir -p "$DOCS/my docs"
doc="$DOCS/my docs/it's \$(x).md"
echo x > "$doc"
click "file://localhost$DOCS/my%20docs/it%27s%20%24(x).md" || fail "exited non-zero"
assert_equals "$(tab_runs | sed -n 4p)" "$doc" "hunk's document argument" &&
  assert_equals "$(sed -n 2p "$MOCK_HUNK_ENV")" "$doc" "hunk's HUNK_SEND_DOC" && pass
teardown_sandbox

it "a name in UTF-8 opens the decoded file"
setup_doc_sandbox
echo x > "$DOCS/café €.md"
click "file://$DOCS/caf%C3%A9%20%E2%82%AC.md" || fail "exited non-zero"
assert_equals "$(tab_runs | sed -n 4p)" "$DOCS/café €.md" "hunk's document argument" && pass
teardown_sandbox

it "the empty file is emptied again on each click"
setup_doc_sandbox
mkdir -p "$HOME/.cache/hunk-docs"
echo stale > "$HOME/.cache/hunk-docs/empty"
click "file://$DOCS/spec.md"
assert_equals "$(wc -c < "$HOME/.cache/hunk-docs/empty" | tr -d ' ')" 0 "the empty file's size" && pass
teardown_sandbox

it "a link to another host opens nothing and says why"
setup_doc_sandbox
click "file://example.com$DOCS/spec.md" && fail "exited zero"
assert_equals "$(herdr_call tab create)" "" "tab create" &&
  assert_contains "$(notified)" "another host" "the notification" && pass
teardown_sandbox

it "a missing file opens nothing and says why"
setup_doc_sandbox
click "file://$DOCS/gone.md" && fail "exited zero"
assert_equals "$(herdr_call tab create)" "" "tab create" &&
  assert_contains "$(notified)" "No such file: $DOCS/gone.md" "the notification" && pass
teardown_sandbox

it "a folder named like a document opens nothing"
setup_doc_sandbox
mkdir -p "$DOCS/dir.md"
click "file://$DOCS/dir.md" && fail "exited zero"
assert_equals "$(herdr_call tab create)" "" "tab create" && pass
teardown_sandbox

it "a control character in the name, encoded or not, opens nothing and says why"
setup_doc_sandbox
ok=1
for url in "file://$DOCS/a%0Ab.md" "file://$DOCS/a%00b.md" "file://$DOCS/a%7fb.md" "file://$DOCS/a%C2%9Bb.md" "file://$DOCS/a"$'\xc2\x9b'"b.md" "file://$DOCS/a"$'\t'"b.md"; do
  : > "$MOCK_HERDR_LOG"
  click "$url" && { fail "exited zero on $url"; ok=""; break; }
  assert_equals "$(herdr_call tab create)" "" "tab create for $url" &&
    assert_contains "$(notified)" "control character" "the notification for $url" || { ok=""; break; }
done
[ -n "$ok" ] && pass
teardown_sandbox

it "a broken escape or a backslash, encoded or not, opens nothing and says why, even where its misreading exists"
setup_doc_sandbox
echo x > "$DOCS/aA.md"
ok=1
for url in "file://$DOCS/a%zz.md:broken % escape" "file://$DOCS/a%4.md:broken % escape" "file://$DOCS/a\\x41.md:backslash" "file://$DOCS/a%5Cx41.md:backslash"; do
  why="${url##*:}" url="${url%:*}"
  : > "$MOCK_HERDR_LOG"
  click "$url" && { fail "exited zero on $url"; ok=""; break; }
  assert_equals "$(herdr_call tab create)" "" "tab create for $url" &&
    assert_contains "$(notified)" "$why" "the notification for $url" || { ok=""; break; }
done
[ -n "$ok" ] && pass
teardown_sandbox

it "a link naming this machine, in any case, opens the file"
setup_doc_sandbox
ok=1
here="$(hostname)"
for host in "$here" "$(printf '%s' "$here" | tr '[:lower:]' '[:upper:]')" "$(printf '%s' "$here" | tr '[:upper:]' '[:lower:]')" LOCALHOST; do
  : > "$MOCK_HERDR_LOG"
  click "file://$host$DOCS/spec.md" || { fail "exited non-zero for $host"; ok=""; break; }
  assert_equals "$(tab_runs | sed -n 4p)" "$DOCS/spec.md" "hunk's document argument for $host" || { ok=""; break; }
done
[ -n "$ok" ] && pass
teardown_sandbox

it "with hunk not installed it opens nothing and says so"
setup_doc_sandbox
rm "$MOCK_BIN/hunk"
click "file://$DOCS/spec.md" && fail "exited zero"
assert_equals "$(herdr_call tab create)" "" "tab create" &&
  assert_contains "$(notified)" "hunk is not installed" "the notification" && pass
teardown_sandbox

it "a tab herdr refuses runs nothing and says why"
setup_doc_sandbox
MOCK_TAB_FAIL=1 click "file://$DOCS/spec.md" && fail "exited zero"
assert_equals "$(herdr_call pane run)" "" "pane run" &&
  assert_contains "$(notified)" "workspace_not_found" "the notification" && pass
teardown_sandbox

it "a warning herdr prints while opening the tab does not stop it"
setup_doc_sandbox
MOCK_TAB_WARN=1 click "file://$DOCS/spec.md" || fail "exited non-zero"
assert_equals "$(herdr_call pane run | sed -n 3p)" "w1:p9" "the pane run in" && pass
teardown_sandbox

it "a tab herdr opens with no pane runs nothing and says so"
setup_doc_sandbox
MOCK_TAB_NOPANE=1 click "file://$DOCS/spec.md" && fail "exited zero"
assert_equals "$(herdr_call pane run)" "" "pane run" &&
  assert_contains "$(notified)" "herdr opened no pane" "the notification" && pass
teardown_sandbox

it "the link handler takes file links to .md and .markdown files only"
pattern="$(sed -n 's/^pattern = "\(.*\)"$/\1/p' "$PLUGIN/herdr-plugin.toml" | sed 's/\\\\/\\/g')"
bad=""
for url in file:///a/b.md file:///a/b.markdown; do [[ "$url" =~ $pattern ]] || bad="$bad $url"; done
for url in file:///a/b.mdx https://a/b.md file:///a/b.md.diff file:///a/.whiska/review/x; do
  [[ "$url" =~ $pattern ]] && bad="$bad $url"
done
[ -n "$pattern" ] && [ -z "$bad" ] && pass || fail "pattern '$pattern' got wrong:$bad"

it "is linked into herdr by install"
assert_contains "$(cat "$REPO_ROOT/install.conf.yaml")" 'herdr plugin link "$PWD/herdr_plugins/hunk-docs"' "install.conf.yaml" &&
  [ -x "$OPEN" ] && pass || fail "open-doc.sh is not executable"
