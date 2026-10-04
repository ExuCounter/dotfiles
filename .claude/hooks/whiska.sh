#!/usr/bin/env bash
# Whiska's hooks. Takes the hook's name - pre-tool-use or stop - and hands
# the payload on stdin to `whiska hook <name>`.
#
# Written by `whiska init` and checked into the repo so the rules travel with
# it (ADR-0016). Everything machine-specific is resolved here, when the hook
# runs, rather than baked into .claude/settings.json where it would name one
# developer's home directory and one Erlang version.
#
# A hook does not necessarily inherit an interactive shell's PATH, so every
# lookup ends by searching the filesystem directly rather than trusting it.
# WHISKA_BIN and WHISKA_ESCRIPT override either, and are ignored if they do
# not point at something runnable.

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

# Fail open, loudly. A missing Whiska must never brick every tool call in a
# session - the same trade Whiska.Hook.PreToolUse makes on a bad payload.
if [ -z "$whiska_bin" ]; then
  echo "whiska: not found - allowing the call (set WHISKA_BIN to fix)" >&2
  exit 0
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

if [ -n "$escript_bin" ]; then
  # Not `exit 0`: exec carries the hook's status out, and the doctor reads it
  # to tell a working hook from a binary that does not know it.
  exec "$escript_bin" "$whiska_bin" hook "$@"
fi

# No runtime anywhere. Whiska may be a native binary that needs none
# (ADR-0033), so try it directly - and fail open if that does not work.
if ! "$whiska_bin" hook "$@"; then
  echo "whiska: could not run $whiska_bin - allowing the call" >&2
fi
exit 0
