# bin/spaces-smart-merge.sh: after a Herdr update, the shipped spaces main.js
# goes onto the upstream branch and merges into the branch checked out, so
# spaces-smart's own changes merge three-way. Each test runs on a throwaway
# repo laid out as dotfiles is, with the script copied into it.

MOD="herdr-app/mods/spaces-smart/main.js"

# A repo whose upstream holds shipped lines a..e and whose master changed b.
merge_setup() {
  setup_sandbox
  R="$SANDBOX/dotfiles"
  mkdir -p "$R/bin" "$R/herdr-app/mods/spaces-smart"
  git -C "$R" init -q -b master
  git -C "$R" config user.name test && git -C "$R" config user.email test@example.com
  printf 'a\nb\nc\nd\ne\n' > "$R/$MOD"
  git -C "$R" add . && git -C "$R" commit -qm shipped && git -C "$R" branch upstream
  printf 'a\nb mine\nc\nd\ne\n' > "$R/$MOD"
  git -C "$R" commit -qam mine
  cp "$REPO_ROOT/bin/spaces-smart-merge.sh" "$R/bin/"
  SHIPPED="$SANDBOX/shipped.js"
}

merge_run() { out="$("$R/bin/spaces-smart-merge.sh" "$SHIPPED" 2>&1)"; code=$?; }

it "an unchanged shipped file merges nothing"
merge_setup
printf 'a\nb\nc\nd\ne\n' > "$SHIPPED"
before="$(git -C "$R" rev-parse master upstream)"
merge_run
assert_equals "$code" 0 "exit code" &&
  assert_equals "$(git -C "$R" rev-parse master upstream)" "$before" "master and upstream" &&
  assert_contains "$out" "nothing to merge" && pass
teardown_sandbox

it "a changed shipped file is committed onto upstream and merged with spaces-smart's changes"
merge_setup
printf 'a\nb\nc\nd\ne new\n' > "$SHIPPED"
old_upstream="$(git -C "$R" rev-parse upstream)"
merge_run
assert_equals "$code" 0 "exit code" &&
  assert_equals "$(git -C "$R" rev-parse upstream~1)" "$old_upstream" "upstream's parent" &&
  assert_equals "$(git -C "$R" show "upstream:$MOD")" "$(cat "$SHIPPED")" "upstream's main.js" &&
  assert_equals "$(cat "$R/$MOD")" "$(printf 'a\nb mine\nc\nd\ne new')" "merged main.js" &&
  assert_equals "$(git -C "$R" rev-parse master^2)" "$(git -C "$R" rev-parse upstream)" "the merge's second parent" &&
  assert_equals "$(git -C "$R" branch --show-current)" master "branch checked out" && pass
teardown_sandbox

it "a line both sides changed stops in a conflict, upstream already committed"
merge_setup
printf 'a\nb theirs\nc\nd\ne\n' > "$SHIPPED"
merge_run
[ "$code" -ne 0 ] || fail "expected a non-zero exit"
assert_equals "$(git -C "$R" show "upstream:$MOD")" "$(cat "$SHIPPED")" "upstream's main.js" &&
  assert_contains "$(git -C "$R" status --porcelain)" "UU $MOD" "git status" &&
  assert_contains "$out" "conflict" &&
  assert_equals "$(git -C "$R" branch --show-current)" master "branch checked out" && pass
teardown_sandbox

it "a merge left unfinished last time is merged again, upstream untouched"
merge_setup
printf 'a\nb\nc\nd\ne new\n' > "$SHIPPED"
merge_run
git -C "$R" reset -q --hard HEAD~1
upstream_now="$(git -C "$R" rev-parse upstream)"
merge_run
assert_equals "$code" 0 "exit code" &&
  assert_equals "$(git -C "$R" rev-parse upstream)" "$upstream_now" "upstream" &&
  assert_equals "$(cat "$R/$MOD")" "$(printf 'a\nb mine\nc\nd\ne new')" "merged main.js" && pass
teardown_sandbox
