# herdr-app/mods/spaces-smart/smart.mjs: the spaces-smart mod's own logic
# (repo groups, the worktree line), pure so node's runner tests it without
# the app. Each node test reports here as one case.

SMART_TESTS="$REPO_ROOT/tests/spaces-smart.test.mjs"

if ! command -v node >/dev/null; then
  it "node runs the spaces-smart tests"
  fail "node is not on PATH"
else
  smart_out="$(node --test --test-reporter=tap "$SMART_TESTS" 2>&1)"
  while IFS= read -r line; do
    case "$line" in
      "ok "*) it "${line#ok * - }"; pass ;;
      "not ok "*) it "${line#not ok * - }"; fail "node --test $SMART_TESTS" ;;
    esac
  done <<< "$smart_out"
fi
