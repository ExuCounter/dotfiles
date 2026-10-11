---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question, letter its options, and give your recommended answer. Then wait for the user's answers before the next round.

Format a round like so:

```
❓ **Q1** - **<question title>**: <the problem, in one plain line>

- **A** — <an option and what it costs>
- **B** — <another option and what it costs>

➡️ **A**: <why, in one line>

---

❓ **Q2** - **<question title>**: <the problem, in one plain line>

- **A** — <an option and what it costs>
- **B** — <another option and what it costs>

➡️ **B**: <why, in one line>

Reply e.g. "1A 2B".
```

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.

## In a Whiska mouse

- A build from a **Proposed build** takes its Found as fact, asks its Open choices and
  still grills the design of the build.
- A mouse that only investigates, a sniff mouse, grills the research question only: goal,
  the decision it feeds, scope, depth, what to deliver. Skip it when the brief already
  answers those, and never grill design there.
