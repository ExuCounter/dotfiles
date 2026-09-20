#!/usr/bin/env bash
# Tests for bin/frontend-preview-shot.sh
#
# The browser is mocked: a fake binary on PATH records the args it was called
# with and writes a PNG of a controlled size, so we can drive every branch
# (missing browser, silent no-output, blank capture) without launching Chrome.
#
# Run: tests/frontend-preview-shot.test.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUT="$REPO/bin/frontend-preview-shot.sh"

pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
no()   { fail=$((fail+1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }
check(){ [ "$2" = "$3" ] && ok "$1" || no "$1" "expected [$3], got [$2]"; }

# --- mock browser -----------------------------------------------------------
# Writes $MOCK_BYTES bytes of valid-PNG-magic output to the --screenshot path,
# records argv to $ARGS_LOG, and exits $MOCK_EXIT.
setup() {
  TMP="$(mktemp -d)"
  BIN="$TMP/bin"; mkdir -p "$BIN"
  ARGS_LOG="$TMP/args"
  cat > "$BIN/mockbrowser" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$ARGS_LOG"
out=""
for a in "$@"; do case "$a" in --screenshot=*) out="${a#--screenshot=}";; esac; done
if [ "${MOCK_WRITE:-1}" = 1 ] && [ -n "$out" ]; then
  { printf '\211PNG\r\n\032\n'; head -c "$((${MOCK_BYTES:-50000} - 8))" /dev/zero | tr '\0' 'A'; } > "$out"
fi
exit "${MOCK_EXIT:-0}"
MOCK
  chmod +x "$BIN/mockbrowser"
  export ARGS_LOG
  export FRONTEND_PREVIEW_BROWSER="$BIN/mockbrowser"
  unset MOCK_WRITE MOCK_EXIT MOCK_BYTES
}
teardown() { rm -rf "$TMP"; unset FRONTEND_PREVIEW_BROWSER ARGS_LOG; }

echo "frontend-preview-shot"

# --- 1. exists and is executable --------------------------------------------
[ -x "$SUT" ] && ok "script exists and is executable" \
              || { no "script exists and is executable" "$SUT missing"; echo; echo "$pass passed, $((fail+1)) failed"; exit 1; }

# --- 2. usage ---------------------------------------------------------------
setup
"$SUT" >/dev/null 2>&1; check "no args -> exit 64 (usage)" "$?" 64
teardown

# --- 3. happy path ----------------------------------------------------------
setup
out="$TMP/shots/a.png"
MOCK_BYTES=60000 "$SUT" "http://localhost:3000/x" "$out" >/dev/null 2>&1
check "capture succeeds -> exit 0" "$?" 0
[ -f "$out" ] && ok "creates output file (and its parent dir)" \
              || no "creates output file (and its parent dir)" "no file at $out"
teardown

# --- 4. browser args --------------------------------------------------------
setup
MOCK_BYTES=60000 "$SUT" --width 900 --height 640 "http://x.test/" "$TMP/b.png" >/dev/null 2>&1
grep -qx -- "--headless" "$ARGS_LOG" && ok "passes --headless" || no "passes --headless" "$(tr '\n' ' ' < "$ARGS_LOG")"
grep -qx -- "--window-size=900,640" "$ARGS_LOG" && ok "passes requested --window-size" || no "passes requested --window-size" "$(tr '\n' ' ' < "$ARGS_LOG")"
grep -qx -- "--screenshot=$TMP/b.png" "$ARGS_LOG" && ok "passes absolute --screenshot path" || no "passes absolute --screenshot path" "$(tr '\n' ' ' < "$ARGS_LOG")"
teardown

# --- 5. url handling --------------------------------------------------------
setup
MOCK_BYTES=60000 "$SUT" "http://localhost:3000/keep?a=1" "$TMP/c.png" >/dev/null 2>&1
grep -qx -- "http://localhost:3000/keep?a=1" "$ARGS_LOG" && ok "http URL passed through unchanged" || no "http URL passed through unchanged" "$(tr '\n' ' ' < "$ARGS_LOG")"
teardown

setup
printf '<p>hi</p>' > "$TMP/page.html"
( cd "$TMP" && MOCK_BYTES=60000 "$SUT" page.html "$TMP/d.png" >/dev/null 2>&1 )
grep -qx -- "file://$TMP/page.html" "$ARGS_LOG" && ok "relative local path -> absolute file:// URL" || no "relative local path -> absolute file:// URL" "$(tr '\n' ' ' < "$ARGS_LOG")"
teardown

# --- 6. no browser ----------------------------------------------------------
setup
# NB: don't clobber PATH here - the script's own `env bash` shebang needs it,
# and a broken shebang exits 127, which would pass for the wrong reason.
FRONTEND_PREVIEW_BROWSER="$TMP/nope" "$SUT" "http://x.test/" "$TMP/e.png" >/dev/null 2>&1
check "explicit browser override that isn't executable -> exit 3" "$?" 3

setup
FRONTEND_PREVIEW_BROWSER="$TMP" "$SUT" "http://x.test/" "$TMP/e2.png" >/dev/null 2>&1
check "explicit browser override pointing at a directory -> exit 3" "$?" 3
teardown

# --- 7. silent failure: browser exits 0 but writes nothing ------------------
setup
MOCK_WRITE=0 "$SUT" "http://x.test/" "$TMP/f.png" >/dev/null 2>&1
check "browser exits 0 but writes no file -> exit 2" "$?" 2
teardown

# --- 8. stale output must not masquerade as success -------------------------
setup
stale="$TMP/g.png"; printf '\211PNG\r\n\032\nSTALE-BUT-BIG' > "$stale"
head -c 60000 /dev/zero | tr '\0' 'A' >> "$stale"
MOCK_WRITE=0 "$SUT" "http://x.test/" "$stale" >/dev/null 2>&1
check "stale output file is cleared first -> exit 2" "$?" 2
[ ! -f "$stale" ] && ok "stale output file removed, not left behind" || no "stale output file removed, not left behind" "still present"
teardown

# --- 9. blank detection -----------------------------------------------------
# 1280x900 = 1152000 px. Measured: blank ~0.0046 B/px, real content ~0.054 B/px.
setup
MOCK_BYTES=5000 "$SUT" "http://x.test/" "$TMP/h.png" >/dev/null 2>&1   # 0.0043 B/px
check "blank-looking capture -> exit 4" "$?" 4
teardown

setup
MOCK_BYTES=60000 "$SUT" "http://x.test/" "$TMP/i.png" >/dev/null 2>&1  # 0.052 B/px
check "content-bearing capture -> exit 0" "$?" 0
teardown

setup
MOCK_BYTES=5000 "$SUT" --allow-blank "http://x.test/" "$TMP/j.png" >/dev/null 2>&1
check "--allow-blank bypasses the blank check" "$?" 0
teardown

# --- 10. not a PNG ----------------------------------------------------------
setup
cat > "$BIN/mockbrowser" <<'MOCK2'
#!/usr/bin/env bash
for a in "$@"; do case "$a" in --screenshot=*) head -c 60000 /dev/zero | tr '\0' 'Z' > "${a#--screenshot=}";; esac; done
MOCK2
chmod +x "$BIN/mockbrowser"
"$SUT" "http://x.test/" "$TMP/k.png" >/dev/null 2>&1
check "output without PNG magic bytes -> exit 5" "$?" 5
teardown

# --- 11. browser failure propagates ----------------------------------------
setup
MOCK_EXIT=1 MOCK_WRITE=0 "$SUT" "http://x.test/" "$TMP/l.png" >/dev/null 2>&1
check "browser non-zero exit -> non-zero" "$([ $? -ne 0 ] && echo nonzero)" "nonzero"
teardown

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
