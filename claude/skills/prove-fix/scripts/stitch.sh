#!/usr/bin/env bash
# Joins clips into one 1440x900 H.264 mp4 and writes a contact sheet beside it.
#   stitch.sh <out.mp4> <clip.webm>[@<speed>]...
# "@3" plays that clip at 3x. Prints the final duration in seconds.
set -euo pipefail

[ $# -ge 2 ] || { echo "usage: stitch.sh <out.mp4> <clip>[@<speed>]..." >&2; exit 64; }
out="$1"; shift
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

index=0
for spec in "$@"; do
  clip="$spec"
  speed=1
  if [[ "$spec" =~ @([0-9]+([.][0-9]+)?)$ ]]; then
    clip="${spec%@*}"
    speed="${BASH_REMATCH[1]}"
  fi
  python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) > 0 else 1)" "$speed" || { echo "stitch.sh: speed must be above 0 in $spec" >&2; exit 64; }
  [ -s "$clip" ] || { echo "stitch.sh: no clip at $clip" >&2; exit 66; }
  index=$((index + 1))
  part="$work/$(printf '%03d' "$index").mp4"
  ffmpeg -nostdin -y -v error -i "$clip" \
    -vf "scale=1440:900:force_original_aspect_ratio=decrease,pad=1440:900:(ow-iw)/2:(oh-ih)/2,setpts=PTS/$speed,fps=30" \
    -an -c:v libx264 -pix_fmt yuv420p -crf 20 "$part"
  printf "file '%s'\n" "$part" >> "$work/list.txt"
done

ffmpeg -nostdin -y -v error -f concat -safe 0 -i "$work/list.txt" -c copy -movflags +faststart "$out"
duration="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out")"
interval="$(python3 -c "print(max(float('$duration') / 12, 0.5))")"
ffmpeg -nostdin -y -v error -i "$out" -vf "fps=1/$interval,scale=480:-1,tile=4x3" -frames:v 1 "${out%.*}.sheet.png"
echo "$duration"
