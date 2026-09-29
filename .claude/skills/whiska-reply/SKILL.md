---
name: whiska-reply
description: Answer a question one of this repo's mice is waiting on. Use when the person has decided what to tell a mouse, or on /whiska-reply.
---

Run exactly this:

    whiska reply $ARGUMENTS

If they did not spell the id out — they are answering a question you just
showed them — the id is the one from that delivered line, and the command is

    whiska reply <id> "<what they said>"

The text is the person's own words, or the option they picked, quoted. Not
your summary of them, not an answer you worked out yourself: answering is
their move and this only carries it.

## And nothing else

This is the only way to answer a mouse. Never type the answer into the
mouse's pane with `herdr agent prompt`, and never send it with
`send-to-worktree`. The mouse would read it, but the question would stay
`sent`: it keeps holding Whiska's one delivery slot, and the next mouse's
question sits unread behind it. Only `whiska reply` closes the question and
frees the slot.

Talking it over with the person first is fine. When that talk produces
something for the mouse, it goes out as the reply.
