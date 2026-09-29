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
printf '%s\n' "$@" >> "$ARGS_LOG"
out=""
for a in "$@"; do case "$a" in --screenshot=*) out="${a#--screenshot=}";; esac; done
if [ "${MOCK_WRITE:-1}" = 1 ] && [ -n "$out" ]; then
  { printf '\211PNG\r\n\032\n'; head -c "$((${MOCK_BYTES:-50000} - 8))" /dev/zero | tr '\0' 'A'; } > "$out"
fi
exit "${MOCK_EXIT:-0}"
MOCK
  chmod +x "$BIN/mockbrowser"
  : > "$ARGS_LOG"
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
teardown

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

# --- 11. the file is the signal, not the browser's exit status --------------
# Chrome exits non-zero on macOS over display-link errors while writing a
# perfectly good screenshot, so the script judges the file. These two pin that
# both ways round.
setup
MOCK_EXIT=1 MOCK_BYTES=60000 "$SUT" "http://x.test/" "$TMP/l.png" >/dev/null 2>&1
check "browser exits non-zero but wrote a good PNG -> exit 0" "$?" 0
teardown

setup
MOCK_EXIT=0 MOCK_WRITE=0 "$SUT" "http://x.test/" "$TMP/l2.png" >/dev/null 2>&1
check "browser exits zero but wrote nothing -> exit 2" "$?" 2
teardown

# --- 11b. a two-argument option missing its value must not spin -------------
# `shift 2` with one argument left is a no-op returning non-zero, which without
# `set -e` loops the parser forever. Each of these used to hang.
for opt in --width --height --wait --like; do
  setup
  ( "$SUT" "$opt" >/dev/null 2>&1 ) & spin=$!
  ( sleep 5; kill -9 $spin 2>/dev/null ) & watchdog=$!
  wait $spin 2>/dev/null; rc=$?
  kill $watchdog 2>/dev/null
  check "trailing $opt with no value -> exit 64, no hang" "$rc" 64
  teardown
done

# --- 11c. each dimension is validated on its own ----------------------------
# Concatenating them let an empty height hide behind a non-empty width, which
# made the pixel count zero and silently disabled the blank check.
setup
MOCK_BYTES=60000 "$SUT" --width 1280 --height "" "http://x.test/" "$TMP/l3.png" >/dev/null 2>&1
check "empty --height -> exit 64, not a skipped blank check" "$?" 64
teardown

setup
MOCK_BYTES=60000 "$SUT" --width 0 --height 900 "http://x.test/" "$TMP/l4.png" >/dev/null 2>&1
check "zero --width -> exit 64" "$?" 64
teardown


# --- 12. --stable: has the page finished rendering? -------------------------
# The mock reads one size per invocation from $SIZES, so a run can be scripted
# as "small, then bigger, then bigger again" — a page still pulling in webfonts.
setup_sizing() {
  setup
  SIZES="$TMP/sizes"
  cat > "$BIN/mockbrowser" <<'MOCK3'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$ARGS_LOG"
n=0; [ -f "$SIZES.n" ] && n="$(cat "$SIZES.n")"
size="$(sed -n "$((n + 1))p" "$SIZES")"
[ -n "$size" ] || size="$(tail -1 "$SIZES")"
echo $((n + 1)) > "$SIZES.n"
for a in "$@"; do case "$a" in --screenshot=*) out="${a#--screenshot=}";; esac; done
{ printf '\211PNG\r\n\032\n'; head -c "$((size - 8))" /dev/zero | tr '\0' 'A'; } > "$out"
MOCK3
  chmod +x "$BIN/mockbrowser"
  export SIZES
  : > "$ARGS_LOG"
}

setup_sizing
printf '60000\n60100\n' > "$SIZES"
"$SUT" --stable --wait 1000 "http://x.test/" "$TMP/m.png" >/dev/null 2>&1
check "--stable: two agreeing captures -> exit 0" "$?" 0
grep -qx -- "--virtual-time-budget=2000" "$ARGS_LOG" && ok "--stable re-captures at double the wait" || no "--stable re-captures at double the wait" "$(tr '\n' ' ' < "$ARGS_LOG")"
teardown

setup_sizing
printf '30000\n60000\n120000\n' > "$SIZES"
"$SUT" --stable --wait 1000 "http://x.test/" "$TMP/n.png" >/dev/null 2>&1
check "--stable: picture keeps changing -> exit 6" "$?" 6
teardown

setup_sizing
# Settles on the second probe, not the first: still a pass.
printf '30000\n60000\n60200\n' > "$SIZES"
"$SUT" --stable --wait 1000 "http://x.test/" "$TMP/o.png" >/dev/null 2>&1
check "--stable: settles on the longer wait -> exit 0" "$?" 0
teardown

setup_sizing
printf '30000\n90000\n90100\n' > "$SIZES"
"$SUT" --stable --wait 1000 "http://x.test/" "$TMP/p.png" >/dev/null 2>&1
kept="$( { stat -f%z "$TMP/p.png" 2>/dev/null || stat -c%s "$TMP/p.png" 2>/dev/null; } )"
check "--stable keeps the longer-waited capture, not the first" "$kept" "90100"
teardown

setup
MOCK_BYTES=60000 "$SUT" "http://x.test/" "$TMP/q.png" >/dev/null 2>&1
[ "$(grep -c -- '--screenshot=' "$ARGS_LOG")" = 1 ] && ok "no --stable -> exactly one capture" || no "no --stable -> exactly one capture" "$(grep -c -- '--screenshot=' "$ARGS_LOG") captures"
teardown

# --- 13. --like: did the page keep its stylesheet? --------------------------
# A page that rendered with no CSS is a dense, valid PNG — every other check
# here passes it. It is only distinguishable by colour, so these fixtures are
# real PNGs: a canvas colour with a band of accent across some of the rows.
# The unstyled case is the one that matters — bare white, almost no accent.
# <path> <r,g,b canvas> <r,g,b accent> <accent rows> [filter 0-4] [colour type 2|6]
# Chrome's own captures use filters 1-4 and colour type 6, so the filter and
# colour type are parameters: the unfiltering is the most bug-prone code here
# and filter 0 exercises none of it.
make_png() {
  python3 - "$@" <<'PYEOF'
import sys, zlib, struct
path, canvas, accent, rows = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
ftype = int(sys.argv[5]) if len(sys.argv) > 5 else 0
ctype = int(sys.argv[6]) if len(sys.argv) > 6 else 2
canvas = tuple(int(v) for v in canvas.split(','))
accent = tuple(int(v) for v in accent.split(','))
channels = 4 if ctype == 6 else 3
w, h = 200, 200

rows_raw = []
for y in range(h):
    colour = accent if y < rows else canvas
    px = bytes(colour) + (b'\xff' if channels == 4 else b'')
    rows_raw.append(bytearray(px * w))

def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    return a if pa <= pb and pa <= pc else (b if pb <= pc else c)

raw = b''
prev = bytearray(len(rows_raw[0]))
for line in rows_raw:
    enc = bytearray(len(line))
    for x in range(len(line)):
        a = line[x - channels] if x >= channels else 0
        b = prev[x]
        c = prev[x - channels] if x >= channels else 0
        if ftype == 0:   enc[x] = line[x]
        elif ftype == 1: enc[x] = (line[x] - a) & 255
        elif ftype == 2: enc[x] = (line[x] - b) & 255
        elif ftype == 3: enc[x] = (line[x] - (a + b) // 2) & 255
        elif ftype == 4: enc[x] = (line[x] - paeth(a, b, c)) & 255
    raw += bytes([ftype]) + bytes(enc)
    prev = line

def chunk(typ, body):
    return struct.pack('>I', len(body)) + typ + body + struct.pack('>I', zlib.crc32(typ + body))
png = (b'\x89PNG\r\n\x1a\n'
       + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, ctype, 0, 0, 0))
       + chunk(b'IDAT', zlib.compress(raw))
       + chunk(b'IEND', b''))
open(path, 'wb').write(png)
PYEOF
}

# The mock hands back a prepared fixture instead of a byte count.
setup_fixture() {
  setup
  cat > "$BIN/mockbrowser" <<'MOCK4'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$ARGS_LOG"
for a in "$@"; do case "$a" in --screenshot=*) cp "$FIXTURE" "${a#--screenshot=}";; esac; done
MOCK4
  chmod +x "$BIN/mockbrowser"
  export FIXTURE
}

if ! command -v python3 >/dev/null 2>&1; then
  ok "SKIPPED --like palette tests (no python3)"
else

setup_fixture
ref="$TMP/ref.png"; make_png "$ref" 248,250,252 37,99,235 20
FIXTURE="$TMP/shot.png"; make_png "$FIXTURE" 255,255,255 0,0,0 1
"$SUT" --allow-blank --like "$ref" "http://x.test/" "$TMP/r.png" >/dev/null 2>&1
check "unstyled capture: white canvas, no chrome -> exit 7" "$?" 7
teardown

setup_fixture
ref="$TMP/ref.png"; make_png "$ref" 248,250,252 37,99,235 20
FIXTURE="$TMP/shot.png"; make_png "$FIXTURE" 248,250,252 37,99,235 26
"$SUT" --allow-blank --like "$ref" "http://x.test/" "$TMP/s.png" >/dev/null 2>&1
check "capture sharing the reference's canvas and chrome -> exit 0" "$?" 0
teardown

setup_fixture
# Same canvas, but flattened: every card and border gone.
ref="$TMP/ref.png"; make_png "$ref" 248,250,252 37,99,235 20
FIXTURE="$TMP/shot.png"; make_png "$FIXTURE" 248,250,252 37,99,235 1
"$SUT" --allow-blank --like "$ref" "http://x.test/" "$TMP/u.png" >/dev/null 2>&1
check "capture far flatter than the reference -> exit 7" "$?" 7
teardown

# Every filter type, and the RGBA colour type Chrome actually writes: if the
# unfiltering were wrong the decoded canvas would not match and these would
# misreport a matching pair as a palette mismatch.
for ft in 0 1 2 3 4; do
  setup_fixture
  ref="$TMP/ref.png"; make_png "$ref" 248,250,252 37,99,235 20 "$ft" 6
  FIXTURE="$TMP/shot.png"; make_png "$FIXTURE" 248,250,252 37,99,235 20 "$ft" 6
  "$SUT" --allow-blank --like "$ref" "http://x.test/" "$TMP/ft$ft.png" >/dev/null 2>&1
  check "filter type $ft, RGBA: identical images read as matching -> exit 0" "$?" 0
  teardown
done

for ft in 1 4; do
  setup_fixture
  ref="$TMP/ref.png"; make_png "$ref" 248,250,252 37,99,235 20 "$ft" 6
  FIXTURE="$TMP/shot.png"; make_png "$FIXTURE" 255,255,255 0,0,0 1 "$ft" 6
  "$SUT" --allow-blank --like "$ref" "http://x.test/" "$TMP/ftu$ft.png" >/dev/null 2>&1
  check "filter type $ft, RGBA: unstyled still caught -> exit 7" "$?" 7
  teardown
done

# --stable and --like each need a scratch directory. A second `trap ... EXIT`
# replaces the first rather than stacking, which leaked the probe directory on
# every run that used both.
setup_fixture
ref="$TMP/ref.png"; make_png "$ref" 248,250,252 37,99,235 20
FIXTURE="$TMP/shot.png"; make_png "$FIXTURE" 248,250,252 37,99,235 20
scratch="$TMP/scratch"; mkdir -p "$scratch"
TMPDIR="$scratch" "$SUT" --allow-blank --stable --wait 1000 --like "$ref" "http://x.test/" "$TMP/lk.png" >/dev/null 2>&1
left="$(find "$scratch" -maxdepth 1 -name 'fps-*' | grep -c . || true)"
check "--stable with --like leaves no scratch directory behind" "$left" "0"
teardown

setup_fixture
# --allow-palette-shift is the deliberate bypass for a recoloured option.
ref="$TMP/ref.png"; make_png "$ref" 248,250,252 37,99,235 20
FIXTURE="$TMP/shot.png"; make_png "$FIXTURE" 255,255,255 0,0,0 1
"$SUT" --allow-blank --allow-palette-shift --like "$ref" "http://x.test/" "$TMP/aps.png" >/dev/null 2>&1
check "--allow-palette-shift bypasses the --like check" "$?" 0
teardown

setup_fixture
# A reference it cannot parse is not evidence the capture is broken.
ref="$TMP/ref.png"; printf '\211PNG\r\n\032\nnot really a png' > "$ref"
FIXTURE="$TMP/shot.png"; make_png "$FIXTURE" 248,250,252 37,99,235 20
"$SUT" --allow-blank --like "$ref" "http://x.test/" "$TMP/v.png" >/dev/null 2>&1
check "unreadable --like reference -> warns, does not fail the capture" "$?" 0
teardown

fi

setup
MOCK_BYTES=60000 "$SUT" --like "$TMP/absent.png" "http://x.test/" "$TMP/t.png" >/dev/null 2>&1
check "--like pointing at a missing file -> exit 64" "$?" 64
teardown

# python3 is the palette reader's dependency, not the script's: without it the
# capture still succeeds and the caller is told the check was skipped.
setup_fixture
ref="$TMP/ref.png"; make_png "$ref" 248,250,252 37,99,235 20 2>/dev/null || printf '\211PNG\r\n\032\nx' > "$ref"
FIXTURE="$TMP/shot.png"; cp "$ref" "$FIXTURE"
err="$(FRONTEND_PREVIEW_PYTHON="$TMP/no-such-python" "$SUT" --allow-blank --like "$ref" "http://x.test/" "$TMP/w.png" 2>&1 >/dev/null)"
status=$?
check "no python3 on PATH -> capture still succeeds" "$status" 0
case "$err" in *python3*) ok "no python3 -> says the check was skipped" ;;
                       *) no "no python3 -> says the check was skipped" "stderr: $err" ;; esac
teardown

# This file keeps its own counters (it predates tests/lib.sh), so hand them to
# the shared tally run.sh reads — without this the runner counts zero and stays
# green no matter what happens in here.
TESTS_RUN=$(( ${TESTS_RUN:-0} + pass + fail ))
TESTS_FAILED=$(( ${TESTS_FAILED:-0} + fail ))

[ "$fail" -eq 0 ]
