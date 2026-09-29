---
paths:
  - "**/*.{tsx,jsx,vue,svelte,astro,html,heex,css,scss,less}"
---
# Frontend changes — preview before building

When a task changes what I'd see in a browser, do not go straight to code. Use the
`frontend-preview` skill first: it captures the current state, mocks up 2-3 directions
using the project's real design tokens, and publishes one Artifact page with before,
after, and the options side by side. Then it stops and waits for me to pick.

The test for whether this applies is one question: **would a screenshot of the app look
different after this change?** New page, redesign, layout, component, styling, or copy
on a visible surface — yes. Renamed route, query tuning, a test, build config — no, even
if the request mentions a UI word in passing.

Skip it — out loud, in one line, never silently — when the change has exactly one
sensible form (a typo, a colour I already named), when I gave you a mock or screenshot
to match, or when I say to just build it.

While waiting for my pick, write **no** implementation code, not even the scaffolding.
Pre-building your recommended option skips this step while appearing to follow it. This
gate comes before the TDD rule: pick the direction first, then write the failing
test for it.

