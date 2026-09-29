#!/bin/bash
#
# @raycast.schemaVersion 1
# @raycast.title Jump to What Needs Me
# @raycast.mode silent
# @raycast.packageName Whiska
# @raycast.icon 🐱
# @raycast.description Focus the mouse with the oldest waiting question, in any repo.

set -u

# Raycast inherits no shell PATH. whiska is an escript, so escript must be
# findable too; asdf's shims cover it when they are on PATH.
export PATH="$HOME/.local/bin:$HOME/.asdf/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# No shell environment here either, so name herdr's default socket (ADR-0040).
export HERDR_SOCKET_PATH="${HERDR_SOCKET_PATH:-$HOME/.config/herdr/herdr.sock}"

open -a kitty
whiska jump
