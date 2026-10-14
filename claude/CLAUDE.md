## Frontend preview

If a screenshot of the app would look different after a change, run the
`frontend-preview` skill — but only in a build session, after the spec is written and I
have approved it, and before any implementation code. Never while grilling, never before
the spec, never while investigating. Invoking it is how you ask; don't ask permission.
Borderline counts as yes. The skill itself says when to skip.

## Verify before claiming "done"

Never report something as working without running it. "Done" means: relevant tests green,
typecheck clean, and — for user-facing flows — exercised end to end (e.g. Playwright for web
flows). If tests fail or a step was skipped, say so plainly with the output.

## Reporting

When reporting information to me, be extremely concise and sacrifice grammar for sake of concision.
