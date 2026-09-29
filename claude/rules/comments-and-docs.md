---
paths:
  - "**/*.{ex,exs,ts,tsx,js,jsx,py,rb,go,rs,sh,lua}"
---
# Comments and docs

Default to no comments. Behaviour is pinned by a test with a descriptive name, not by
prose. A comment is the exception, for a non-obvious why that no test can carry. When in
doubt, no comment.

- A comment does not restate the code, a function or symbol name, or a doc comment that
  already covers the point.
- The simpler and more declarative the code, the less it needs a comment or a doc
  comment. When the text would be longer than the code it describes, such as a function
  returning a constant or a single comparison, the reader gets there faster by reading
  the code, so the text is left out.
- A comment describes the code on its own terms, not by contrast with a previous version
  or an alternative that was not picked. Write "parses to nil so it surfaces as unknown",
  not "parses to nil instead of raising like it did before". Phrases like "instead of",
  "no longer", "used to" and "would otherwise" usually narrate the diff.
- No comment explains why something is absent.
- No ticket ids in comments or doc comments. A ticket reference belongs in the commit
  message.
- A doc comment on a function earns its place only when it says something the name and
  signature do not. One that repeats the name in a sentence is removed.
- A module or file doc describes the module on its own terms, not as what it replaces or
  through its neighbours. On an event or message type it states the fact the event
  announces, not who handles it or why it was added. Naming the handlers couples the
  event to them.
- In tests the name carries the behaviour, so a comment above a describe block or test
  case that paraphrases the names is removed.
- When one redundant comment is removed, every comment of the same kind in the diff goes
  with it.
