#!/usr/bin/env bash
# Whiska's project statusline (ADR-0027). A project-level statusLine
# replaces the global one rather than merging with it, so this runs your
# global statusline first and appends this repo's own line: what is
# waiting in this house, and how many mice are alive here. Nothing is
# appended when the repo is quiet.
#
# The owl's state and the machine-wide view are not here: they are drawn
# once on herdr's tab bar (ADR-0048).
#
# Written by `whiska init`. The binary and runtime are resolved the same
# way the hook shim resolves them, at run time, never baked in here.

input="$(cat)"

global=""
if command -v jq >/dev/null 2>&1 && [ -r "$HOME/.claude/settings.json" ]; then
  global="$(jq -r '.statusLine.command // empty' "$HOME/.claude/settings.json" 2>/dev/null)"
fi

base=""
case "$global" in
  "" | *whiska-statusline.sh*) ;;
  *) base="$(printf '%s' "$input" | bash -c "$global" 2>/dev/null)" ;;
esac

dir=""
if command -v jq >/dev/null 2>&1; then
  dir="$(printf '%s' "$input" | jq -r '.workspace.current_dir // .workspace.project_dir // .cwd // empty' 2>/dev/null)"
fi
[ -d "$dir" ] || dir="$PWD"

whiska_bin="${WHISKA_BIN:-}"
if [ -n "$whiska_bin" ] && [ ! -x "$whiska_bin" ]; then
  whiska_bin=""
fi
if [ -z "$whiska_bin" ]; then
  whiska_bin="$(command -v whiska 2>/dev/null)" || whiska_bin=""
fi
if [ -z "$whiska_bin" ] && [ -x "$HOME/.local/bin/whiska" ]; then
  whiska_bin="$HOME/.local/bin/whiska"
fi

# An escript begins `#!/usr/bin/env escript`, so it only runs when escript is
# on PATH. With a version manager in play it is not found at all - and asking
# the version manager does not help when it is off PATH too, which is exactly
# the case a hook lands in. So the last resort reads its install directory.
escript_bin="${WHISKA_ESCRIPT:-}"
if [ -n "$escript_bin" ] && [ ! -x "$escript_bin" ]; then
  escript_bin=""
fi
if [ -z "$escript_bin" ]; then
  escript_bin="$(command -v escript 2>/dev/null)" || escript_bin=""
fi
if [ -z "$escript_bin" ] && command -v asdf >/dev/null 2>&1; then
  escript_bin="$(asdf which escript 2>/dev/null)" || escript_bin=""
fi
if [ -z "$escript_bin" ]; then
  escript_bin="$(ls -1 "${ASDF_DATA_DIR:-$HOME/.asdf}"/installs/erlang/*/bin/escript     2>/dev/null | sort -V | tail -1)"
fi
if [ -z "$escript_bin" ]; then
  for candidate in /opt/homebrew/bin/escript /usr/local/bin/escript; do
    if [ -x "$candidate" ]; then
      escript_bin="$candidate"
      break
    fi
  done
fi

segment=""
if [ -n "$whiska_bin" ] && [ -n "$escript_bin" ]; then
  segment="$(cd "$dir" && "$escript_bin" "$whiska_bin" statusline --here 2>/dev/null)"
elif [ -n "$whiska_bin" ]; then
  segment="$(cd "$dir" && "$whiska_bin" statusline --here 2>/dev/null)"
fi

if [ -n "$base" ] && [ -n "$segment" ]; then
  printf '%s · %s' "$base" "$segment"
else
  printf '%s%s' "$base" "$segment"
fi
