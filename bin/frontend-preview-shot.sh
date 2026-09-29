#!/usr/bin/env bash
#
# frontend-preview-shot.sh — capture one headless screenshot, and fail loudly
# when the capture didn't actually work.
#
# Used by the `frontend-preview` Claude skill. The value here is not "run a
# browser" (one line) — it's the checking around it. A screenshot step fails
# silently in four ways that all look like success: the browser exits 0 and
# writes nothing, it writes a stale file from a previous run, it writes a
# perfectly valid PNG of a blank page, or it writes a real page captured before
# its webfonts and stylesheet landed. Each one ends with a human being shown a
# broken-looking picture and concluding the *design* is wrong. This exits
# non-zero instead.
#
#   frontend-preview-shot.sh [options] <url-or-path> <output.png>
#
#   --width N        viewport width  (default 1280)
#   --height N       viewport height (default 900)
#   --wait MS        let the page settle/hydrate before capturing
#   --stable         re-capture at a longer wait and require the two to agree
#   --like REF.png   require this capture to share REF.png's palette
#   --allow-palette-shift  skip the --like check (for a deliberate recolour)
#   --allow-blank    skip the blank-capture check (for genuinely empty states)
#
# Exit codes — distinct so a caller can tell the failures apart:
#   0  captured, validated
#   2  browser produced no output file
#   3  no usable browser
#   4  capture looks blank
#   5  output is not a PNG
#   6  page never settled (--stable: longer waits kept changing the picture)
#   7  capture looks unstyled next to --like reference
#   64 usage error
#
# Env:
#   FRONTEND_PREVIEW_BROWSER      explicit browser binary (no fallback if set)
#   FRONTEND_PREVIEW_MIN_DENSITY  blank threshold, bytes per pixel
#   FRONTEND_PREVIEW_PYTHON       python3 binary the --like check reads with
#   FRONTEND_PREVIEW_STABLE_TOL        --stable agreement tolerance (default 0.01)
#   FRONTEND_PREVIEW_LIKE_CHANNEL_TOL  --like colour drift per channel (default 2)
#   FRONTEND_PREVIEW_LIKE_SHARE_TOL    --like extra flatness allowed (default 0.05)

set -uo pipefail

WIDTH=1280
HEIGHT=900
WAIT_MS=""
ALLOW_BLANK=0
ALLOW_PALETTE_SHIFT=0
STABLE=0
LIKE=""

# Measured on real captures at 1280x900: a blank white page lands at ~0.0046
# bytes/pixel, a page containing only the character "x" at ~0.0049, and real
# content at 0.054-0.063. The thinnest legitimate capture observed was 0.0141.
# 0.008 sits ~1.7x above blank and ~1.8x below that thinnest real capture.
MIN_DENSITY="${FRONTEND_PREVIEW_MIN_DENSITY:-0.008}"

# Headless rendering is deterministic: the same page at 500ms, 2000ms and
# 8000ms of virtual time was byte-identical across all three in testing, so a
# settled page has no compression noise to leave room for. The tolerance exists
# only for genuinely live content (a clock, a rotating avatar). It has to stay
# small: swapping a whole heading webfont moved a sparse page by just 3.5%.
STABLE_TOL="${FRONTEND_PREVIEW_STABLE_TOL:-0.01}"

# --like judges two measured signals against the reference, and file size is
# deliberately not one of them: the unstyled page this check exists to catch
# measured 0.73x the reference's bytes, indistinguishable from a design that
# simply has less on it. Colour separates them cleanly instead.
#
# CHANNEL_TOL: how far the dominant colour may drift per channel. Large flat
# fills carry no antialiasing, so three independent captures of the same page
# agreed exactly; 2 is slack, not tolerance. It has to stay tight because the
# gap being caught is small — slate-50 canvas (248,250,252) against the bare
# white (255,255,255) a page falls back to with no stylesheet.
#
# SHARE_TOL: how much flatter than the reference the capture may be. An
# unstyled page is one colour across 99.6% of the viewport where the styled
# page was 91.8%, because every card, fill and border is gone.
LIKE_CHANNEL_TOL="${FRONTEND_PREVIEW_LIKE_CHANNEL_TOL:-2}"
LIKE_SHARE_TOL="${FRONTEND_PREVIEW_LIKE_SHARE_TOL:-0.05}"

PYTHON="${FRONTEND_PREVIEW_PYTHON:-python3}"

# Reads the dominant colour and how much of the viewport it covers, for the
# reference and the capture, and exits 7 when they disagree. Exits 2 on
# anything it cannot read, which the caller downgrades to a warning: a palette
# it failed to parse is not evidence the page is broken.
write_palette_reader() {
  cat > "$1" <<'PYEOF'
import sys, zlib, struct
from collections import Counter

def pixels(path):
    d = open(path, 'rb').read()
    if d[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('%s is not a PNG' % path)
    pos, idat, plte = 8, [], None
    w = h = depth = ctype = None
    while pos + 8 <= len(d):
        ln = struct.unpack('>I', d[pos:pos+4])[0]
        typ = d[pos+4:pos+8]
        body = d[pos+8:pos+8+ln]
        if typ == b'IHDR':
            w, h, depth, ctype = struct.unpack('>IIBB', body[:10])
            if body[12]:
                raise ValueError('%s is interlaced' % path)
        elif typ == b'IDAT':
            idat.append(body)
        elif typ == b'PLTE':
            plte = body
        elif typ == b'IEND':
            break
        pos += 12 + ln
    if depth != 8:
        raise ValueError('only 8-bit PNGs are readable here (got %s)' % depth)
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    stride = w * channels
    # A capture is a screenshot, so its dimensions are bounded by a viewport,
    # and those dimensions say exactly how many bytes the image data holds.
    # Inflating to that limit and no further means a crafted reference cannot
    # expand to gigabytes, however its IDAT was built.
    if w > 8000 or h > 8000:
        raise ValueError('%s is %dx%d, too large to be a capture' % (path, w, h))
    expected = h * (stride + 1)
    raw = zlib.decompressobj().decompress(b''.join(idat), expected)
    if len(raw) < expected:
        raise ValueError('%s has truncated image data' % path)

    out, prev = bytearray(), bytearray(stride)
    i = 0
    for _ in range(h):
        f = raw[i]; i += 1
        line = bytearray(raw[i:i+stride]); i += stride
        if f:
            for x in range(stride):
                a = line[x-channels] if x >= channels else 0
                b = prev[x]
                c = prev[x-channels] if x >= channels else 0
                if f == 1: line[x] = (line[x] + a) & 255
                elif f == 2: line[x] = (line[x] + b) & 255
                elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
                elif f == 4:
                    p = a + b - c
                    pa, pb, pc = abs(p-a), abs(p-b), abs(p-c)
                    line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        out += line
        prev = line
    return w, h, channels, ctype, plte, bytes(out)

def dominant(path):
    # Every 4th pixel each way: 16x less work, and a flat fill this is looking
    # for cannot hide from a grid that coarse.
    w, h, channels, ctype, plte, px = pixels(path)
    seen = Counter()
    for y in range(0, h, 4):
        base = y * w * channels
        for x in range(0, w, 4):
            o = base + x * channels
            if ctype == 3:
                idx = px[o] * 3
                seen[tuple(plte[idx:idx+3])] += 1
            elif channels >= 3:
                seen[tuple(px[o:o+3])] += 1
            else:
                seen[(px[o],) * 3] += 1
    colour, count = seen.most_common(1)[0]
    return colour, count / sum(seen.values())

try:
    ref_path, shot_path, channel_tol, share_tol = sys.argv[1:5]
    channel_tol, share_tol = int(channel_tol), float(share_tol)
    ref_colour, ref_share = dominant(ref_path)
    shot_colour, shot_share = dominant(shot_path)
    if len(ref_colour) != 3 or len(shot_colour) != 3:
        raise ValueError('truncated palette in %s or %s' % (ref_path, shot_path))
    drift = max(abs(a - b) for a, b in zip(ref_colour, shot_colour))
except Exception as exc:
    print(exc)
    sys.exit(2)

flatter = shot_share - ref_share
problems = []
if drift > channel_tol:
    problems.append('background is rgb%s where the reference is rgb%s' % (shot_colour, ref_colour))
if flatter > share_tol:
    problems.append('one colour covers %.1f%% of it against the reference\'s %.1f%%'
                    % (shot_share * 100, ref_share * 100))
if problems:
    print('; '.join(problems))
    sys.exit(7)
sys.exit(0)
PYEOF
}

die() { printf 'frontend-preview-shot: %s\n' "$1" >&2; exit "$2"; }

# One handler for every scratch directory. Two `trap ... EXIT` calls would not
# stack — the second silently replaces the first — so each new directory
# registers itself here instead.
PROBE_DIR=""
READER_DIR=""
cleanup() {
  [ -n "$PROBE_DIR" ] && rm -rf "$PROBE_DIR"
  [ -n "$READER_DIR" ] && rm -rf "$READER_DIR"
  return 0
}
trap cleanup EXIT INT TERM

usage() {
  sed -n '15,32p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 64
}

# `shift 2` with one argument left is a no-op that returns non-zero, and
# without `set -e` that silently spins this loop forever on the same $1.
needs_value() { [ "$2" -ge 2 ] || die "$1 needs a value" 64; }

while [ $# -gt 0 ]; do
  case "$1" in
    --width)       needs_value "$1" $#; WIDTH="$2"; shift 2 ;;
    --height)      needs_value "$1" $#; HEIGHT="$2"; shift 2 ;;
    --wait)        needs_value "$1" $#; WAIT_MS="$2"; shift 2 ;;
    --like)        needs_value "$1" $#; LIKE="$2"; shift 2 ;;
    --stable)      STABLE=1; shift ;;
    --allow-blank) ALLOW_BLANK=1; shift ;;
    --allow-palette-shift) ALLOW_PALETTE_SHIFT=1; shift ;;
    -h|--help)     usage ;;
    --)            shift; break ;;
    -*)            die "unknown option: $1" 64 ;;
    *)             break ;;
  esac
done

[ $# -eq 2 ] || usage
TARGET="$1"
OUT="$2"

# Checked separately: concatenating them lets an empty one hide behind a
# non-empty one, and a zero pixel count silently disables the blank check.
case "$WIDTH" in *[!0-9]*|"") die "--width must be a positive integer" 64 ;; esac
case "$HEIGHT" in *[!0-9]*|"") die "--height must be a positive integer" 64 ;; esac
{ [ "$WIDTH" -gt 0 ] && [ "$HEIGHT" -gt 0 ]; } || die "--width and --height must be greater than zero" 64
[ -z "$WAIT_MS" ] || case "$WAIT_MS" in *[!0-9]*) die "--wait must be an integer" 64 ;; esac
[ -z "$LIKE" ] || [ -f "$LIKE" ] || die "--like reference '$LIKE' does not exist" 64

# --- resolve the browser ----------------------------------------------------
# An explicit override that doesn't exist is a configuration mistake, not a
# reason to quietly use a different browser than the caller asked for.
if [ -n "${FRONTEND_PREVIEW_BROWSER:-}" ]; then
  # -x alone is not enough: directories are "executable" too.
  { [ -f "$FRONTEND_PREVIEW_BROWSER" ] && [ -x "$FRONTEND_PREVIEW_BROWSER" ]; } \
    || die "FRONTEND_PREVIEW_BROWSER is set to '$FRONTEND_PREVIEW_BROWSER' but that is not an executable file" 3
  BROWSER="$FRONTEND_PREVIEW_BROWSER"
else
  BROWSER=""
  for c in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
    google-chrome chromium chromium-browser
  do
    if [ -f "$c" ] && [ -x "$c" ]; then BROWSER="$c"; break; fi
    if command -v "$c" >/dev/null 2>&1; then BROWSER="$(command -v "$c")"; break; fi
  done
  [ -n "$BROWSER" ] || die "no headless-capable browser found; install Chrome or set FRONTEND_PREVIEW_BROWSER" 3
fi

# --- normalise the target into a URL ---------------------------------------
case "$TARGET" in
  http://*|https://*|file://*|about:*|data:*)
    URL="$TARGET" ;;
  *)
    if [ -e "$TARGET" ]; then
      d="$(cd "$(dirname "$TARGET")" && pwd)" || die "cannot resolve directory of '$TARGET'" 64
      URL="file://$d/$(basename "$TARGET")"
    else
      die "'$TARGET' is not a URL and does not exist on disk" 64
    fi ;;
esac

# --- normalise the output path ---------------------------------------------
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
mkdir -p "$(dirname "$OUT")" || die "cannot create output directory for '$OUT'" 2

file_size() { { stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null; } | head -1; }

# --- capture ----------------------------------------------------------------
# Chrome prints CVDisplayLink / task_policy_set errors on macOS and still
# succeeds, so the exit code is not the signal here. The file is.
#
# capture_to <dest> <wait_ms>  — leaves $bytes set to the captured size.
capture_to() {
  local dest="$1" wait_ms="$2" status

  # A leftover file from a previous run is indistinguishable from a fresh capture.
  rm -f "$dest"

  set -- --headless --disable-gpu --hide-scrollbars \
         --force-color-profile=srgb --font-render-hinting=none \
         --run-all-compositor-stages-before-draw \
         "--window-size=$WIDTH,$HEIGHT" "--screenshot=$dest"
  [ -n "$wait_ms" ] && set -- "$@" "--virtual-time-budget=$wait_ms"
  set -- "$@" "$URL"

  "$BROWSER" "$@" >/dev/null 2>&1
  status=$?

  [ -f "$dest" ] || die "browser exited $status and produced no file at $dest" 2

  bytes="$(file_size "$dest")"
  [ -n "$bytes" ] && [ "$bytes" -gt 0 ] 2>/dev/null \
    || { rm -f "$dest"; die "capture at $dest is empty" 2; }

  local magic
  magic="$(head -c 8 "$dest" | od -An -tx1 | tr -d ' \n')"
  [ "$magic" = "89504e470d0a1a0a" ] \
    || die "output at $dest is not a PNG (magic: ${magic:-none})" 5
}

capture_to "$OUT" "$WAIT_MS"

# --- did the page finish rendering? -----------------------------------------
# --virtual-time-budget pauses the virtual clock while requests are in flight,
# so it already covers most of what a readiness hook would, but it never waits
# on document.fonts.ready and Chrome's screenshot mode offers no hook to add.
# So ask the question empirically: shoot again at twice the budget and see
# whether the picture stopped changing. Agreement means settled; continued
# disagreement means a page that was never going to finish in time.
#
# The limit worth knowing: this detects work still in progress, never a
# resource that fails outright. A webfont Chrome refuses to fetch renders the
# same at every budget, so it settles — looking wrong, consistently.
if [ "$STABLE" -eq 1 ]; then
  # Chrome picks the screenshot encoder off the file extension and writes
  # nothing at all when there isn't one, so the probe cannot be a bare mktemp.
  PROBE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/fps-probe.XXXXXX")" || die "cannot create probe directory" 2
  probe="$PROBE_DIR/probe.png"

  prev_bytes="$bytes"
  settled=0
  next_wait="${WAIT_MS:-1000}"

  for _ in 1 2; do
    next_wait=$((next_wait * 2))
    capture_to "$probe" "$next_wait"
    if awk -v a="$prev_bytes" -v b="$bytes" -v t="$STABLE_TOL" \
       'BEGIN{m=(a>b?a:b); exit !(m>0 && (a>b?a-b:b-a)/m <= t)}'; then
      settled=1
    fi
    # Keep the longer-waited capture either way: it is the more finished page.
    cp "$probe" "$OUT" || die "cannot update $OUT from the probe capture" 2
    bytes="$(file_size "$OUT")"
    [ "$settled" -eq 1 ] && break
    prev_bytes="$bytes"
  done

  [ "$settled" -eq 1 ] || die "capture at $OUT never settled (still changing at ${next_wait}ms).
  The page is probably still loading webfonts, data or a skeleton state. Raise
  --wait, or capture a state that finishes rendering." 6
fi

# --- validate ---------------------------------------------------------------
if [ "$ALLOW_BLANK" -eq 0 ]; then
  pixels=$((WIDTH * HEIGHT))
  # awk, not bc: bc isn't guaranteed present, awk is.
  if awk -v b="$bytes" -v p="$pixels" -v t="$MIN_DENSITY" 'BEGIN{exit !(p>0 && b/p < t)}'; then
    density="$(awk -v b="$bytes" -v p="$pixels" 'BEGIN{printf "%.5f", b/p}')"
    die "capture at $OUT looks blank (${density} bytes/pixel, threshold ${MIN_DENSITY}).
  The page probably had not rendered yet. Try --wait 5000, check the URL is
  serving, or pass --allow-blank if this state really is empty." 4
  fi
fi

# --- does it look like it kept its stylesheet? ------------------------------
# The blank check catches a white page. It does not catch the failure this
# skill actually hits: a page that rendered its markup with no CSS attached —
# unstyled text on bare white, which is a perfectly dense, perfectly valid PNG.
# Only a comparison against a capture known to be right (the "before" shot,
# taken at the same viewport) separates the two, and only on colour: losing the
# stylesheet loses the canvas tint and every fill, border and shadow with it.
#
# Needs python3 to read the pixels. Chrome and bash stay the hard requirement,
# so a machine without python3 skips the check out loud rather than failing.
if [ -n "$LIKE" ] && [ "$ALLOW_PALETTE_SHIFT" -eq 0 ]; then
  if command -v "$PYTHON" >/dev/null 2>&1; then
    READER_DIR="$(mktemp -d "${TMPDIR:-/tmp}/fps-palette.XXXXXX")" || die "cannot create palette reader directory" 2
    write_palette_reader "$READER_DIR/palette.py"
    like_report="$("$PYTHON" "$READER_DIR/palette.py" "$LIKE" "$OUT" \
                     "$LIKE_CHANNEL_TOL" "$LIKE_SHARE_TOL" 2>&1)"
    like_status=$?
    case "$like_status" in
      0) ;;
      7) die "capture at $OUT does not share $LIKE's palette.
  $like_report
  That gap usually means the page rendered without its stylesheet — check the
  CSS actually loaded, and that the reference was shot at the same viewport." 7 ;;
      *) printf 'frontend-preview-shot: --like check could not run (%s); judge the capture by eye\n' \
           "$like_report" >&2 ;;
    esac
  else
    printf 'frontend-preview-shot: --like reads pixels with python3, which is not on PATH (set FRONTEND_PREVIEW_PYTHON); judge the capture by eye\n' >&2
  fi
fi

printf '%s\n' "$OUT"
