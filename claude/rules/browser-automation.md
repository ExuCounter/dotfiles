# Driving a browser

Interactive browser work — clicking, typing, submitting a form, reading the DOM back —
goes through the **chrome-devtools MCP server**. It is configured with `--isolated`, so
each run takes a throwaway profile of its own. Without the flag the server does not grab
your everyday Chrome — it falls back to one shared profile at
`~/.cache/chrome-devtools-mcp/chrome-profile`, which every agent session reaches for at
once. The first session to claim it wins and the rest are refused, so this surfaces only
when more than one session is doing browser work.

Do not hand-roll Chrome DevTools Protocol over `--remote-debugging-port`. A `PreToolUse`
hook blocks it, for three reasons measured on this machine:

- Machine policy disallows remote debugging, so the socket is severed partway through a
  run. The failure reads like a crashing page, which costs a debugging detour.
- Headless Chrome refuses a window narrower than 500px here, so a port-driven "mobile"
  capture is not one — it is a 500px render cropped to phone width.
- Clicking and typing have to be reimplemented, and setting `.value` on an input does not
  reach a Vue or React binding. The event has to be dispatched by hand.

## When the state is behind a login or a long setup

Reaching for the login form is the last resort, not the first.

**Prefer not to travel there at all.** To see a component in some state, mount it
directly — the `render-component` skill, or a throwaway `preview__` route in the real
app. Auth, routing and setup steps stop existing, and the component still renders through
the project's real CSS and compiler.

**Next, inject the session rather than perform it.** Set the cookie or `localStorage`
token before the first render instead of driving a login form, which is slower and breaks
every time that form is redesigned.

**Only if a login must genuinely persist between runs**, swap `--isolated` for
`--userDataDir=<a dedicated path>`. What matters is never sharing the one default profile
every session reaches for; a profile of its own avoids that collision and keeps the
session. `--isolated` stays the default for everything else.

`--browserUrl`, `--wsEndpoint` and `--autoConnect` attach to a browser someone already
signed into by hand. They need a TCP debugging endpoint, which machine policy here
disallows — assume they do not work on this machine until proven otherwise.

`pageId` on the MCP page-scoped tools is a **number**, not the string the page listing
prints.

**"The browser is already running for &lt;profile&gt;"** means `--isolated` has gone missing
from the server's args — a plugin update ships the file without it. Say so and stop; do
not route around it.

Playwright against the installed Chrome is not the escape hatch. Neither is a port, a
second MCP client, or `--browserUrl`. Each of them lands on a profile some other session
already holds, which is the contention `--isolated` exists to remove — so the workaround
reproduces the failure the error was warning about. Playwright is fine when the task is
Playwright, a test or a scripted flow the project already owns; never as a way past this
error.

The fix is `./install` in the dotfiles repo, which puts `--isolated` back on every copy
under `~/.claude/plugins/cache/*/chrome-devtools-mcp/*/`. Patch every copy, not the one
that looks active: Claude Code reads the commit-sha-named directory, while the `.in_use`
markers sit in the version-named one, so the obvious copy is the wrong one. The server is
spawned at session start, so the session has to restart before the flag means anything —
the running process is the one to check (`ps` for `chrome-devtools-mcp`), not the file.

A still frame of a page at rest needs no browser of its own: `frontend-preview-shot.sh`
is enough, and it validates its own captures. It cannot hover, focus or click, so an
interactive state still belongs to the MCP server.
