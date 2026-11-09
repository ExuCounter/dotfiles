---
name: verify
description: Prove the change works before calling it done, by running its checks and showing what came back.
disable-model-invocation: true
---

A change is done when every check that bears on it has run green. Run them now and show
the output; a check that was not run counts as not green.

1. **The repo's checks**: the ones its CLAUDE.md names. When it names none, the test suite,
   the typecheck and the formatter its own config defines (`mix.exs`, `package.json`, a
   `Makefile`).
2. **A flow a user sees**, driven end to end the way a user drives it: a web page through
   Playwright, a command through the built binary. The repo's CLAUDE.md may name its own
   way; that way wins.
3. **Report** one line per check: what ran and what came back. A failure or a skipped check
   goes in plainly, with its output.
