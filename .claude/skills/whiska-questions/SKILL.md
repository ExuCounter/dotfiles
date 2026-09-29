---
name: whiska-questions
description: List the questions waiting on you from this repo's mice. Use when asked what is open, what is waiting, what the mice need, or on /whiska-questions.
---

With no argument, run exactly this:

    whiska questions --full

That is every open question in full, oldest first, with anything orphaned or
still on the doorstep underneath — no id to read off a list and type back.

If the person passed an id ($ARGUMENTS is not empty), run exactly this instead:

    whiska questions $ARGUMENTS

The person cannot see the command's output, only your reply. So your whole
reply is that output, verbatim, inside one fenced code block: every line,
nothing shortened, nothing paraphrased, no commentary before or after. Then
stop. Answering is the person's move — never reply to a question, guess an
answer, or act on one on their behalf.
