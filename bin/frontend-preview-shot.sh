#!/usr/bin/env bash
#
# frontend-preview-shot.sh — capture one headless screenshot, and fail loudly
# when the capture didn't actually work.
#
# Used by the `frontend-preview` Claude skill. The value here is not "run a
# browser" (one line) — it's the checking around it. A screenshot step fails
# silently in three ways that all look like success: the browser exits 0 and
# writes nothing, it writes a stale file from a previous run, or it writes a
# perfectly valid PNG of a blank page. Each one ends with a human being shown
# an empty box and concluding the design is broken. This exits non-zero instead.
#
#   frontend-preview-shot.sh [options] <url-or-path> <output.png>
#
#   --width N        viewport width  (default 1280)
#   --height N       viewport height (default 900)
#   --wait MS        let the page settle/hydrate before capturing
#   --allow-blank    skip the blank-capture check (for genuinely empty states)
#
# Exit codes — distinct so a caller can tell the failures apart:
#   0  captured, validated
#   2  browser produced no output file
#   3  no usable browser
#   4  capture looks blank
#   5  output is not a PNG
#   64 usage error
#
# Env:
#   FRONTEND_PREVIEW_BROWSER      explicit browser binary (no fallback if set)
#   FRONTEND_PREVIEW_MIN_DENSITY  blank threshold, bytes per pixel

set -uo pipefail

WIDTH=1280
HEIGHT=900
WAIT_MS=""
ALLOW_BLANK=0

# Measured on real captures at 1280x900: a blank white page lands at ~0.0046
# bytes/pixel, a page containing only the character "x" at ~0.0049, and real
# content at 0.054-0.063. The thinnest legitimate capture observed was 0.0141.
# 0.008 sits ~1.7x above blank and ~1.8x below that thinnest real capture.
MIN_DENSITY="${FRONTEND_PREVIEW_MIN_DENSITY:-0.008}"

die() { printf 'frontend-preview-shot: %s\n' "$1" >&2; exit "$2"; }

usage() {
  sed -n '7,20p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 64
}

while [ $# -gt 0 ]; do
  case "$1" in
    --width)       WIDTH="${2:-}"; shift 2 ;;
    --height)      HEIGHT="${2:-}"; shift 2 ;;
    --wait)        WAIT_MS="${2:-}"; shift 2 ;;
    --allow-blank) ALLOW_BLANK=1; shift ;;
    -h|--help)     usage ;;
    --)            shift; break ;;
    -*)            die "unknown option: $1" 64 ;;
    *)             break ;;
  esac
done

[ $# -eq 2 ] || usage
TARGET="$1"
OUT="$2"

case "$WIDTH$HEIGHT" in *[!0-9]*|"") die "--width and --height must be integers" 64 ;; esac

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

# A leftover file from a previous run is indistinguishable from a fresh capture.
rm -f "$OUT"

# --- capture ----------------------------------------------------------------
# Chrome prints CVDisplayLink / task_policy_set errors on macOS and still
# succeeds, so the exit code is not the signal here. The file is.
set -- --headless --disable-gpu --hide-scrollbars \
       "--window-size=$WIDTH,$HEIGHT" "--screenshot=$OUT"
[ -n "$WAIT_MS" ] && set -- "$@" "--virtual-time-budget=$WAIT_MS"
set -- "$@" "$URL"

"$BROWSER" "$@" >/dev/null 2>&1
browser_status=$?

# --- validate ---------------------------------------------------------------
[ -f "$OUT" ] || die "browser exited $browser_status and produced no file at $OUT" 2

file_size() { { stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null; } | head -1; }
bytes="$(file_size "$OUT")"
[ -n "$bytes" ] && [ "$bytes" -gt 0 ] 2>/dev/null \
  || { rm -f "$OUT"; die "capture at $OUT is empty" 2; }

magic="$(head -c 8 "$OUT" | od -An -tx1 | tr -d ' \n')"
[ "$magic" = "89504e470d0a1a0a" ] \
  || die "output at $OUT is not a PNG (magic: ${magic:-none})" 5

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

printf '%s\n' "$OUT"
