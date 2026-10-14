# revdiff/patch-trees.sh rebuilds a patch's before and after trees in a scratch
# repo that borrows the source repo's objects, and revdiff/review-diff.sh shows
# them in revdiff, the review tab of a clicked .diff link. Each case builds a
# real repo with a branch and takes its patch the way Whiska does.

TREES="$REPO_ROOT/revdiff/patch-trees.sh"
REVIEW_DIFF="$REPO_ROOT/revdiff/review-diff.sh"

g() { git -C "$SRC" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "$@"; }

# A repo whose feat/x branch edits, adds, deletes, renames (with and without an
# edit), changes a mode and touches a binary file; its patch is in $PATCH.
setup_patch_sandbox() {
  setup_sandbox
  SRC="$SANDBOX/src"
  mkdir -p "$SRC/dir"
  git init -q -b master "$SRC"
  echo .whiska/ >> "$SRC/.git/info/exclude"
  printf 'one\ntwo\nthree\n' > "$SRC/a.txt"
  printf 'gone\n' > "$SRC/gone.txt"
  printf 'same\n' > "$SRC/old-name.md"
  printf 'l1\nl2\nl3\nl4\nl5\nl6\n' > "$SRC/dir/moved.txt"
  printf 'run\n' > "$SRC/tool.sh"
  printf 'x\0y' > "$SRC/pic.bin"
  g add -A && g commit -qm base
  g switch -qc feat/x
  printf 'one\nTWO\nthree\n' > "$SRC/a.txt"
  printf 'fresh\n' > "$SRC/new.txt"
  g rm -q gone.txt
  g mv old-name.md new-name.md
  g mv dir/moved.txt dir/renamed.txt
  printf 'l1\nl2\nl3\nl4\nl5\nL6\n' > "$SRC/dir/renamed.txt"
  chmod +x "$SRC/tool.sh"
  printf 'x\0z' > "$SRC/pic.bin"
  g add -A && g commit -qm change
  mkdir -p "$SRC/.whiska/reviews"
  PATCH="$SRC/.whiska/reviews/feat-x-0123456789abcdef0123456789abcdef.diff"
  g diff --no-color --no-ext-diff --no-textconv --submodule=short master...refs/heads/feat/x -- > "$PATCH"
  SCRATCH="$SANDBOX/scratch"
}

it "rebuilds a real patch's trees so git diff between them prints the same files and hunks"
setup_patch_sandbox
revs="$(bash "$TREES" "$PATCH" "$SRC" "$SCRATCH")"
rebuilt="$(git -C "$SCRATCH" diff --no-color $revs -- 2>&1)"
assert_equals "$rebuilt" "$(cat "$PATCH")" "the rebuilt diff" && pass
teardown_sandbox

it "writes nothing into the source repo"
setup_patch_sandbox
state() { (cd "$SRC/.git" && find . -type f -exec shasum {} + | sort); }
before="$(state)"
bash "$TREES" "$PATCH" "$SRC" "$SCRATCH" >/dev/null
assert_equals "$(state)" "$before" "the files under .git" && pass
teardown_sandbox

it "fails when the source repo lacks the patch's blobs"
setup_patch_sandbox
OTHER="$SANDBOX/other"
git init -q "$OTHER"
bash "$TREES" "$PATCH" "$OTHER" "$SCRATCH" >/dev/null 2>&1
assert_equals "$?" 1 "exit status" && pass
teardown_sandbox

it "fails on a section without an index line that is not a pure rename or mode change"
setup_patch_sandbox
printf 'diff --git a/x b/x\n--- a/x\n+++ b/x\n@@ -1 +1 @@\n-a\n+b\n' > "$PATCH"
bash "$TREES" "$PATCH" "$SRC" "$SCRATCH" >/dev/null 2>&1
assert_equals "$?" 1 "exit status" && pass
teardown_sandbox

# Mock revdiff: records the directory it ran in and its arguments, and, when
# MOCK_NOTE is set, flushes it through the post-flush command and quits with it.
setup_review_diff_sandbox() {
  setup_patch_sandbox
  export MOCK_PROMPT="$SANDBOX/prompt.txt" MOCK_SEEN="$SANDBOX/seen"
  unset MOCK_NOTE
  cat > "$MOCK_BIN/herdr" <<'MOCK'
#!/usr/bin/env bash
[ "$1 $2" = "agent prompt" ] && printf '%s' "$4" >> "$MOCK_PROMPT"
exit 0
MOCK
  cat > "$MOCK_BIN/revdiff" <<'MOCK'
#!/usr/bin/env bash
flush="" output=""
refs=()
for a in "$@"; do
  case "$a" in
    --post-flush-command=*) flush="${a#*=}" ;;
    --output=*) output="${a#*=}" ;;
    -*) ;;
    *) refs+=("$a") ;;
  esac
done
printf '%s\n' "$@" > "$MOCK_SEEN.args"
git ls-files > "$MOCK_SEEN.files"
git diff --no-color "${refs[@]}" -- > "$MOCK_SEEN"
[ -n "${MOCK_NOTE:-}" ] && { printf '%s\n' "$MOCK_NOTE" | "$flush" >/dev/null; printf '%s\n' "$MOCK_NOTE" > "$output"; }
exit 0
MOCK
  chmod +x "$MOCK_BIN/herdr" "$MOCK_BIN/revdiff"
}

it "shows the patch's diff in revdiff"
setup_review_diff_sandbox
bash "$REVIEW_DIFF" "$PATCH" w1:p2 </dev/null >/dev/null
assert_equals "$(cat "$MOCK_SEEN")" "$(cat "$PATCH")" "what revdiff showed" && pass
teardown_sandbox

it "sends a note naming the file and quoting the after side, or the before side for a removed line"
setup_review_diff_sandbox
MOCK_NOTE=$'## a.txt:2 (+)\nwhy caps\n\n## a.txt:2 (-)\nwas fine\n\n## new.txt (file-level)\nneeded?' \
  bash "$REVIEW_DIFF" "$PATCH" w1:p2 </dev/null >/dev/null
assert_equals "$(cat "$MOCK_PROMPT")" "Review notes on $PATCH:

- a.txt line 2 (new) \`TWO\`: why caps
- a.txt line 2 (old) \`two\`: was fine
- new.txt whole file: needed?" "the prompt" && pass
teardown_sandbox

it "reviews the patch as plain text when its trees cannot be rebuilt"
setup_review_diff_sandbox
printf 'diff --git a/x b/x\n--- a/x\n+++ b/x\n@@ -1 +1 @@\n-a\n+b\n' > "$PATCH"
bash "$REVIEW_DIFF" "$PATCH" w1:p2 </dev/null >/dev/null
assert_contains "$(cat "$MOCK_SEEN.args")" "-A" "revdiff's arguments" \
  && assert_equals "$(cat "$MOCK_SEEN.files")" "$(basename "$PATCH")" "the files revdiff browsed" \
  && pass
teardown_sandbox

it "quotes a note on a line that reads like a jq option, and on a removed line of a renamed file"
setup_review_diff_sandbox
printf -- '---\nl2\n' > "$SRC/front.md"; g add -A && g commit -qm more
printf -- '---\nL2\n' > "$SRC/front.md"; g add -A && g commit -qm front
g diff --no-color master...refs/heads/feat/x -- > "$PATCH"
MOCK_NOTE=$'## front.md:1 (+)\nfront matter\n\n## dir/renamed.txt:6 (-)\nwhy\n' \
  bash "$REVIEW_DIFF" "$PATCH" w1:p2 </dev/null >/dev/null
assert_contains "$(cat "$MOCK_PROMPT")" "- front.md line 1 (new) \`---\`: front matter" "the prompt" \
  && assert_contains "$(cat "$MOCK_PROMPT")" "- dir/renamed.txt line 6 (old) \`l6\`: why" "the prompt" \
  && pass
teardown_sandbox

it "rebuilds a patch with a submodule bump and a copy"
setup_patch_sandbox
SUB="$SANDBOX/sub"
git init -q "$SUB" && git -C "$SUB" -c user.email=t@t -c user.name=t commit -q --allow-empty -m one
g switch -q master
g -c protocol.file.allow=always submodule add -q "$SUB" sub && g commit -qm sub
g switch -q feat/x && g merge -q master -m merge
git -C "$SUB" -c user.email=t@t -c user.name=t commit -q --allow-empty -m two
git -C "$SRC/sub" -c protocol.file.allow=always pull -q
cp "$SRC/a.txt" "$SRC/a-copy.txt"
g add -A && g commit -qm bump
g diff -C -C --no-color --no-ext-diff --no-textconv --submodule=short master...refs/heads/feat/x -- > "$PATCH"
revs="$(bash "$TREES" "$PATCH" "$SRC" "$SCRATCH")"
assert_contains "$(cat "$PATCH")" "copy from" "the patch" \
  && assert_contains "$(cat "$PATCH")" "Subproject commit" "the patch" \
  && assert_equals "$(git -C "$SCRATCH" diff -C -C --no-color $revs -- 2>&1)" "$(cat "$PATCH")" "the rebuilt diff" \
  && pass
teardown_sandbox

it "rebuilds copies found by -C: an unchanged copy of an edited file, and a copy whose source is renamed away"
setup_patch_sandbox
g switch -q master
seq 1 50 > "$SRC/m.txt"; printf 'keep\n' > "$SRC/k.txt"; g add -A && g commit -qm m
g switch -q feat/x && g merge -q master -m merge
cp "$SRC/m.txt" "$SRC/m2.txt"; seq 1 49 > "$SRC/m.txt"
cp "$SRC/k.txt" "$SRC/k2.txt"; g mv k.txt k3.txt
g add -A && g commit -qm copies
g -c diff.renames=copies diff -C -C --no-color master...refs/heads/feat/x -- > "$PATCH"
revs="$(bash "$TREES" "$PATCH" "$SRC" "$SCRATCH")"
assert_equals "$(git -C "$SCRATCH" -c diff.renames=copies diff -C -C --no-color $revs -- 2>&1)" "$(cat "$PATCH")" "the rebuilt diff" \
  && assert_equals "$(git -C "$SCRATCH" show "${revs#* }:m2.txt" | wc -l | tr -d ' ')" 50 "the copy's lines" \
  && pass
teardown_sandbox

it "sends notes after the patch file is removed under the open review"
setup_review_diff_sandbox
cat > "$MOCK_BIN/revdiff" <<'MOCK'
#!/usr/bin/env bash
for a in "$@"; do case "$a" in --post-flush-command=*) flush="${a#*=}" ;; esac; done
rm -f "$MOCK_PATCH"
printf '## a.txt:2 (+)\nwhy\n' | "$flush" >/dev/null
exit 0
MOCK
chmod +x "$MOCK_BIN/revdiff"
export MOCK_PATCH="$PATCH"; bash "$REVIEW_DIFF" "$PATCH" w1:p2 </dev/null >/dev/null
assert_contains "$(cat "$MOCK_PROMPT" 2>/dev/null)" "a.txt line 2 (new) \`TWO\`: why" "the prompt" && pass
teardown_sandbox
