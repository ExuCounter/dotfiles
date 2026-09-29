---
paths:
  - "**/*.{tsx,jsx,vue,svelte,astro,html,heex,css,scss,less}"
---
# Frontend changes — preview before building

When a task changes what I'd see in a browser, do not go straight to code. Use the
`frontend-preview` skill first: it captures the current state, renders 2-3 directions
**through the real app**, and publishes one Artifact page with before, after, and the
options side by side. Then it stops and waits for me to pick.

The test for whether this applies is one question: **would a screenshot of the app look
different after this change?** New page, redesign, layout, component, styling, or copy
on a visible surface — yes. Renamed route, query tuning, a test, build config — no, even
if the request mentions a UI word in passing.

Skip it — out loud, in one line, never silently — when the change has exactly one
sensible form (a typo, a colour I already named), when I gave you a mock or screenshot
to match, or when I say to just build it.

The options must be rendered by the project's own CSS pipeline, not hand-written with
invented CSS. A mockup drawn from memory loses the compiled utilities, the webfonts and
the tokens all at once, and I read those losses as the design being wrong. The skill's
rung ladder says how, best option first.

To get that, the skill mounts a throwaway preview route inside the running app. That is
allowed, under three conditions: it lives under `preview__` and is guarded to
development so it is inert if it ever escapes; it only adds a route file plus at most one
branch in an entry point (never edits a real component); and both are deleted after I
pick, before any real code. Do it in a worktree; in my main checkout, drop to a
standalone file linked against the app's real stylesheet, or ask first.

While waiting for my pick, write **no** implementation code, not even the scaffolding.
Pre-building your recommended option skips this step while appearing to follow it. This
gate comes before the TDD rule: pick the direction first, then write the failing
test for it.
