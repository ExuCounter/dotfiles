# Driving a browser

Interactive browser work — clicking, typing, submitting a form, reading the DOM back —
goes through the **chrome-devtools MCP server**. It is configured with `--isolated`, so
it takes a throwaway profile and never collides with a browser some other session left
running.

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
from the server's args — most likely a plugin update restored the defaults. Say so rather
than reaching for a port.

A still frame of a page at rest needs no browser of its own: `frontend-preview-shot.sh`
is enough, and it validates its own captures. It cannot hover, focus or click, so an
interactive state still belongs to the MCP server.
