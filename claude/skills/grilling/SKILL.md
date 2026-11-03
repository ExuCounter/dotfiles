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

Ask only **costly** choices. A choice is costly when something outside the change depends on it (a file format, an interface, stored data, a dependency, behaviour the user would notice), when it touches secrets, access or a security check, or when the rest of the change rests on it. Decide the cheap ones yourself and list them in your report. Ask only what the task leaves open.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.

## In a Whiska mouse

- A build started from an investigation's **What to change** (`whiska spawn build --from
  <id>`) reads its research document and the person's comments on it first, takes its
  findings as fact, and grills only its open choices and the design of the build: a
  choice the comments settle is not asked again.
- A sniff mouse, one that only investigates, grills only the goal, the scope and the
  decision the research feeds. It leaves design to the build, and skips grilling when the
  task already answers those.
