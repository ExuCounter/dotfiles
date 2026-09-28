# Agent-orchestration relay: comparison and implications for an Elixir design

> **Historical.** The bash relay this document describes in the present tense
> (`bin/herdr-worktree-wake.sh`, the two hooks, their tests) was removed on 2026-09-27 in
> favour of Whiska's owl. The comparison and the reasoning it draws out are why the owl is
> shaped the way it is, so the document is kept as written rather than rewritten. Read
> every description of "this repo's" relay as past tense; nothing here still runs.

**Problem statement.** An orchestrator process (the user's main Claude Code session) spawns
worker agent sessions into git worktrees. Workers run asynchronously; when one finishes a
task or hits a human-only decision, that fact — plus the full content of the question —
must reach the orchestrator durably, in order, without being lost when the orchestrator is
busy, restarted, or gone. A reply then has to find its way back to the *specific*
outstanding request. This document compares how five real systems solve that problem, and
closes with what an Elixir/OTP rebuild would look like.

Systems compared:

1. **This dotfiles system** (herdr worktree wake-queue) — source read directly from this repo.
2. **firstmate** (github.com/kunchenguid/firstmate) — source fetched from the repo.
3. **Erlang/OTP `gen_server` call correlation** — the native actor-model answer.
4. **AWS Step Functions callback tasks (task tokens)** — a managed workflow engine's
   human-in-the-loop answer.
5. **RabbitMQ RPC pattern (`correlation_id` + `reply_to`)** — the classic message-broker answer.

---

## 1. Current system: the herdr worktree wake-queue

Sources (this repo, branch `feat/mac-m5`):

- `bin/herdr-worktree-wake.sh` — the queue/relay/delivery script
- `claude/hooks/herdr-worktree-notify.sh` — `Stop` hook (producer side)
- `claude/hooks/herdr-worktree-resume.sh` — `SessionStart` hook (redelivery trigger)
- `claude/CLAUDE.md` — "Worktrees" and "Worktree status marker" sections (the policy)
- `claude/skills/spawn-worktree/SKILL.md`, `claude/skills/send-to-worktree/SKILL.md`
- `tests/herdr-worktree-wake.test.sh`, `tests/herdr-worktree-notify-hook.test.sh`

### Architecture

**Producer (Stop hook).** `herdr-worktree-notify.sh` fires on every completed Claude Code
turn in every session. It walks up from the session's `cwd` (max 8 levels) looking for a
`.herdr-worktree-meta` file — a one-line tab-separated record of
`branch \t worktree-pane-id \t main-pane-id`, written once by `spawn-worktree`. No meta
file → fast no-op (verified by the "is a no-op in an ordinary session" test). If found, it
pipes the assistant's whole `last_assistant_message` into
`herdr-worktree-wake.sh notify`, backgrounded via `nohup` because the hook has a short
harness timeout and delivery can retry for up to a minute.

**Marker protocol.** The worker's contract (from `claude/CLAUDE.md`) is one trailing line
per turn: `[worktree-status: done]` or `[worktree-status: needs-decision] <pointer>`. The
wake script greps for the *last* `[worktree-status: ...]` marker; a turn without one is a
silent no-op. Unrecognized marker kinds are dropped (`*) return 0` in `notify_cmd`).

**Content transport — pointer, not inline.** The whole final message (not just the marker
line) is persisted to a relay file:
`~/.herdr/worktree-relay/<slugified-branch>/<epoch>-<kind>-<pid>-<random>.md`. The
delivered notification is a single line carrying three things: the marker inline, the
relay-file path, and a ready-to-run reply command
(`herdr agent prompt <pane-id> "<your answer>"`). This is forced by the environment:
Claude Code runs on the terminal's alternate screen, so the worker pane's scrollback
cannot be read back (`herdr pane read` returns a truncated tail); and `herdr agent prompt`
submits into a TUI prompt box where an embedded newline would submit early — so the
notification must be one line, and the content must travel as a file.

**Durability and ordering.** The queue is a plain tab-separated append-only file
(`~/.herdr/worktree-wake-queue`), guarded by a `mkdir`-based lock with a 30-second
staleness breaker (and a documented degrade: after 10 s of contention it proceeds
*without* the lock). Delivery (`deliver_branch`) walks a branch's entries oldest-first and
**stops at the first failure**, so ordering is preserved across retries — an earlier
decision round is never overtaken by a later one (verified by the "delivers every queued
entry ... oldest first" test). Each delivery attempt retries up to 20 times at 3-second
intervals; on success the exact line is removed from the queue; on failure it stays queued.
Redelivery is triggered at two natural moments: the next `notify` (any worktree turn
flushes the whole queue) and every `SessionStart` (`resume_cmd` → `flush_all`), which is
exactly when a previously-unreachable main pane becomes reachable again.
`herdr-worktree-wake.sh status` is a pure read — reports stuck entries instantly with no
delivery attempt.

**Retention.** Relay files are pruned by age, not count: anything older than
`HERDR_WAKE_RELAY_KEEP_DAYS` (default 7) is deleted on each notify (verified by the
prune test). Distinct rounds get distinct files — nothing is overwritten.

**Design history baked into the comments.** Two prior designs failed and are documented in
the source: (a) relaying only the marker line meant "5 questions ready, see above" arrived
pointing at unreadable scrollback — hence whole-message relay files; (b) a model-launched
one-shot background poller had to be relaunched after every reply, and a session that
forgot silently killed all future notifications — hence a harness-enforced hook that fires
every turn no matter what any model remembers.

### Delivery guarantee, precisely

At-least-once per queue entry, ordered per branch, with two caveats:

- **Lock degrade**: after 10 s of lock contention the script proceeds unlocked, so a
  concurrent append/remove race is possible (accepted trade-off, logged).
- **Only turn *completions* fire**: a worker that hangs mid-turn never notifies anything.
  `spawn-worktree/SKILL.md` states this plainly: "If the worktree session hangs mid-turn
  and never finishes at all, nothing will ever tell you — there's no separate staleness
  timeout anymore."

### Known gap: no reply correlation

Already researched (finding recorded in this repo's Claude memory, from a prior comparison
against kunchenguid/firstmate): **there is no correlation ID matching a reply to a specific
question.** A reply is just `herdr agent prompt <pane-id> "<text>"` — addressed to a pane,
not to a request. If the same worktree branch raises two decision points concurrently (two
queued `needs-decision` entries, both delivered), nothing binds the human's answer to one
of them; a reply can be misdirected or ambiguously consumed. Related: replies are not
tracked at all — there is no "this question is still unanswered after N minutes" state, so
no escalation on a forgotten reply.

---

## 2. firstmate (kunchenguid/firstmate)

Source verified by fetching:

- https://raw.githubusercontent.com/kunchenguid/firstmate/main/bin/fm-mail.sh
- https://raw.githubusercontent.com/kunchenguid/firstmate/main/bin/fm-send.sh
- https://raw.githubusercontent.com/kunchenguid/firstmate/main/bin/fm-pending-reply-lib.sh
- https://raw.githubusercontent.com/kunchenguid/firstmate/main/bin/fm-procevent-remote-reply.sh

firstmate is the same species of system — bash, files, a wake queue, terminals — but built
out several generations further. Four mechanisms stand out; all four were confirmed
present in the fetched sources.

### 2.1 Durable per-task inbox (`fm-send.sh`)

Messages to a task are appended as "durable sequenced record[s]" under a per-task steering
inbox at `state/<id>.inbox/` (via `fm_task_inbox_write()` /
`fm_task_inbox_write_idempotent()` in `bin/fm-task-inbox-lib.sh`). The durable record
*itself* constitutes delivery; the terminal gets only a best-effort "doorbell" line — the
inverse of the dotfiles design, where the terminal prompt line *is* the delivery and the
file is a side pointer. Idempotent resends carry a caller-supplied 16-hex delivery ID and
the remote leg deduplicates onto the existing record.

### 2.2 Seen-cursor + write-ahead journal (`fm-mail.sh`)

For its mail-ingestion surface, firstmate keeps a seen-cursor (`state/.mail-seen`, UIDs of
already-surfaced messages, with a `uidvalidity=` generation header so a recreated mailbox
can't reuse a numeric UID and suppress a new wake) and an emission journal
(`state/.mail-woken`). `mail_record_evidence()` enforces ordered commitment: the journal
is written *first* — "a mail can never be marked surfaced in the cursor without the
journal recording its wake" — so "a journal entry therefore always means the wake was
published." `mail_heal()` reconstructs state from the journal if the process died between
phases, and `mail_rollback_wake_locked()` removes partial evidence on total failure. This
is crash-safe exactly-once *surfacing* built from flat files. The remote-reply mirror
(`fm-procevent-remote-reply.sh`) does the same with per-stream cursors (offset + SHA-256
prefix digest in `$CURSOR_DIR/$id.cursor`) and ingestion receipts
(`$CURSOR_DIR/$id.$seq.ingested`, payload-hash compared by `ingest_receipt_matches()`),
escalating a `blocked [key=remote-reply-continuity-$id]` decision if the mirrored stream's
history is rewritten under it.

### 2.3 Correlation-ID reply matching (`fm-pending-reply-lib.sh`)

Every marked request mints a 16-hex "privacy-safe correlation id"
(`fm_pending_reply_new_id()`), embeds it in the outgoing message as a `corr=<id>` token
(`fm_pending_reply_embed_corr()`), and records a durable expectation file at
`state/pending-replies/<corr_id>` (schema `fm-pending-reply.v1`, fields for creation
epoch, delivery confirmation, turn completion, recovery, escalation). Replies resolve only
when a status line carries the exact token (`fm_pending_reply_line_resolves()` →
`fm_pending_reply_try_resolve()`); the remote-reply processor greps incoming lines for
`corr=[A-Fa-f0-9]{16}` and resolves each match. Resolved records are kept for audit, never
auto-deleted. This is precisely the mechanism the dotfiles system lacks.

### 2.4 Auto-escalation on stuck replies

An expectation moves through phases `awaiting_report → recovery_sending → recovery_sent →
escalated`. After a grace period (`FM_PENDING_REPLY_GRACE_SECS`, default 120 s) with the
request turn complete and no correlated report, `fm_pending_reply_send_recovery()` sends
exactly one automatic repost; if that also yields nothing,
`fm_pending_reply_maybe_escalate()` opens a durable keyed decision
(`pending-reply-<corr_id>`) in the parent's status log. Escalation happens once per missed
report — never a loop, and records "never silently expire."

**Net:** firstmate demonstrates that inbox-as-delivery, WAL-grade crash safety,
correlation IDs, and bounded escalation are all *achievable* in bash + flat files — at the
cost of roughly an order of magnitude more code and several cooperating state files per
concern.

---

## 3. Erlang/OTP: `gen_server` call correlation

Source: https://www.erlang.org/doc/apps/stdlib/gen_server (official OTP stdlib docs).

The actor model solves the reply-correlation problem natively:

- **Correlation is a unique reference.** A `gen_server:call/2,3` reply destination is a
  `from()` tuple of `{Client :: pid(), Tag :: reply_tag()}`; the tag is the correlation
  identifier. Since OTP 24 the tag is a **process alias**, so "late replies will not be
  received" — a reply to a timed-out or abandoned call is dropped by the runtime, not by
  application code. No ID scheme to design, no registry file: the runtime mints and
  matches the token.
- **Failure detection is built in.** If the server dies mid-call, the caller gets an exit
  with `noproc` / the server's exit term — the request/reply pair is monitored, so "no
  answer because the other side is dead" is a distinct, immediate signal rather than a
  timeout you must invent.
- **Timeouts are first-class.** `call/3` exits the caller with `Reason = timeout` and
  abandons the request (alias deactivated → stray reply discarded).
- **Async multi-request tracking exists in stdlib.** `send_request/2` returns an opaque
  `request_id()`; `receive_response/2` "abandons the request at time-out so that a
  potential future response is ignored" while `wait_response/2` does not; the
  collection variants (`send_request/4`, `receive_response/3`, `wait_response/3`) track
  many outstanding requests with user labels — i.e., stdlib ships the "pending-reply
  registry" as a data structure.

What OTP does **not** give for free: durability. Mailboxes are in-memory; a node restart
loses queued messages and in-flight calls. Durability must be added (ETS +
disk persistence, Mnesia, a database, or an event log).

---

## 4. AWS Step Functions: callback tasks with task tokens

Source: https://docs.aws.amazon.com/step-functions/latest/dg/connect-to-resource.html
(official docs, "Wait for a Callback with Task Token").

A managed workflow engine's version of exactly this human-in-the-loop pattern:

- A task state with the `.waitForTaskToken` suffix on its `Resource` ARN pauses the
  execution and mints a **task token**, exposed in the context object as `$$.Task.Token`
  and passed to the external system (e.g., inside an SQS message body).
- The external process (a human-approval UI, a legacy system) later calls
  `SendTaskSuccess` or `SendTaskFailure` **with that token** — the token is the
  correlation ID binding the reply to the exact paused task instance. Wrong/expired token
  → no effect on any other execution; if a callback task times out, "a new random token is
  generated," so a stale reply can't resume the retried task.
- **Escalation/timeout:** a waiting task can otherwise wait up to the one-year quota;
  `HeartbeatSeconds` plus `SendTaskHeartbeat` bounds it — no valid token activity within
  the interval fails the task with `States.Timeout`, which the state machine can route to
  an escalation branch.
- Durability and ordering are the service's problem: execution state is persisted by the
  engine; delivery of the token to the external side rides whatever transport you chose
  (SQS, SNS, Lambda).

This is the "buy it" end of the spectrum: token minting, correlation, persistence, and
timeout are all engine features; you write none of it.

---

## 5. RabbitMQ RPC pattern (`correlation_id` + `reply_to`)

Source: https://www.rabbitmq.com/tutorials/tutorial-six-python (official tutorial 6).

The classic broker-mediated request/reply, worth including because it names the exact
failure mode the dotfiles system has:

- The client declares one callback queue and sets two message properties on each request:
  `reply_to` (the callback queue) and a unique `correlation_id`. The server echoes the
  `correlation_id` on its response.
- The tutorial's stated rationale is the dotfiles gap verbatim: with "a single callback
  queue per client ... having received a response in that queue it's not clear to which
  request the response belongs. That's when the `correlation_id` property is used."
  (The main pane *is* a single callback queue per client.)
- Delivery guarantee is at-least-once with consumer acks
  (`ch.basic_ack(delivery_tag=...)`); the tutorial explicitly warns that a server dying
  after replying but before acking will reprocess the request, so clients must "handle the
  duplicate responses gracefully" — i.e., correlation IDs also serve as the dedup key.
- Ordering is per-queue FIFO; durability is opt-in per queue/message; escalation/timeout
  is not provided — the client owns its own wait.

---

## Comparison table

| Axis | Dotfiles wake-queue | firstmate | OTP `gen_server` | Step Functions task token | RabbitMQ RPC |
|---|---|---|---|---|---|
| **Content transport** | Pointer: one-line notification into the TUI prompt + full message in a relay file (`~/.herdr/worktree-relay/<branch>/`) | Durable inbox record *is* the delivery (`state/<id>.inbox/`); terminal gets a best-effort doorbell; large docs fetched by pointer (`report=data/...md`) | Inline: message term lands in the receiver's in-memory mailbox | Inline payload via chosen transport (SQS/SNS/Lambda); token travels inside it | Inline message body on a broker queue |
| **Crash-safety / delivery guarantee** | At-least-once: append-only queue file, entry removed only after confirmed delivery, 20×3 s retries, reflush on next turn + SessionStart. Caveats: lock degrades after 10 s; hung mid-turn worker never signals | Exactly-once surfacing via WAL: journal written before cursor (`mail_record_evidence()`), heal/rollback on partial failure, idempotent resends by delivery ID, ingestion receipts by payload hash | None across restarts: mailboxes are in-memory; within a running node, monitored calls detect a dead peer immediately | Engine-persisted execution state; reply is an API call retried by the caller; stale tokens rejected | At-least-once with consumer acks; documented duplicate-on-crash case, client dedups by `correlation_id` |
| **Ordering** | Per-branch FIFO, oldest-first, halt-on-first-failure so order survives retries | Per-stream cursors (offset + digest); continuity break is a detected, escalated event | Per sender→receiver pair, guaranteed by the runtime | Per execution: the state machine is sequential by construction | Per-queue FIFO |
| **Reply→request correlation** | **None** — reply addressed to a pane, not a request (the known gap) | 16-hex `corr=<id>` embedded in the message + durable expectation record `state/pending-replies/<corr_id>`; exact-token match on resolve | `reply_tag()` / process alias minted per call by the runtime; `request_id()` for async; late replies dropped automatically | Task token minted per paused task; `SendTaskSuccess/Failure(taskToken)`; regenerated on timeout | `correlation_id` property echoed by the server, matched by the client |
| **Escalation / timeout on a stuck reply** | None (and no signal at all for a hung mid-turn worker) | Grace period (120 s default) → one automatic recovery repost → one durable keyed escalation decision; never loops, never silently expires | `call/3` timeout exits the caller; monitors turn peer death into an immediate error; supervisors restart | `HeartbeatSeconds` + `SendTaskHeartbeat`; missed heartbeat → `States.Timeout`, routable to an escalation branch | None built in; client-owned wait |
| **Implementation complexity** | ~265-line bash script + two small hooks + a meta file; tested | Several cooperating bash libraries, many state files per concern, remote (ssh) legs; substantially larger | Runtime primitives — near-zero code for correlation/monitoring; durability is the part you write | Managed service: config (ASL JSON) + IAM, no correlation code; vendor lock-in and AWS-only | A broker deployment + ~50 lines per client/server; correlation code is yours but trivial |

---

## Implications for an Elixir design

The one-sentence version: **most of what both bash systems hand-roll is an OTP primitive,
and the two things OTP does not give you — durability across restarts and the human's
terminal as an endpoint — are the only parts you'd actually have to build.**

### What OTP gives for free (that bash had to build)

| Hand-rolled in bash | OTP equivalent |
|---|---|
| firstmate's 16-hex `corr=` token + `state/pending-replies/<id>` registry; dotfiles' *missing* correlation | `GenServer.call` reply tag (a process alias since OTP 24) or an explicit `make_ref()`; for many outstanding requests, `GenServer.send_request/receive_response` with its request-id collection. Uniqueness, matching, and late-reply discard are runtime semantics, not code |
| Flat relay-file directory + one-line TUI notifications | The process mailbox: any term, any size, delivered whole and in order per sender. The "alternate screen makes content unreadable" constraint that forced pointer files disappears entirely |
| 20×3 s retry loop, reflush on SessionStart, `mkdir` lock with staleness breaker | Supervision trees restart a crashed deliverer; `Process.monitor/1` turns "orchestrator is down" into an immediate `:DOWN` message instead of 20 failed prompt attempts; no file locks because a single GenServer serializes access to its own state |
| Dotfiles' blind spot: a hung worker never signals | A monitor on the worker process (or its port/OS-process wrapper) fires `:DOWN` on crash; a `Process.send_after/3` per outstanding request implements firstmate's grace-period → recovery → escalate ladder in a few lines of `handle_info` |
| firstmate's seen-cursor + WAL for exactly-once surfacing | Needed only at the durability boundary (below); in-VM, message delivery per pair is ordered and not duplicated |
| Per-branch FIFO with halt-on-failure | Per-process mailbox ordering, or one GenServer per worktree (via a `Registry`) so each branch's conversation is trivially serialized |

### Concrete shape of an Elixir version

- **One `WorktreeSession` GenServer per worker**, started under a `DynamicSupervisor`,
  registered by branch name in a `Registry`. It owns that worker's OS process (a `Port` or
  something like the `MuonTrap`/erlexec approach — supervise the external Claude process)
  and its conversation state. The dotfiles per-branch queue-and-ordering logic collapses
  into "it's one process's mailbox."
- **Decision points as data, not markers.** The worker-side hook still exists (Claude Code
  is still the agent), but it POSTs/pipes the turn into the Elixir node instead of a queue
  file. The session GenServer parses the marker, creates a `DecisionPoint` struct with an
  ID (`make_ref()` is perfect in-VM; use a UUID/ULID the moment it must survive restarts
  or appear in a UI/CLI), and hands it to an `Orchestrator.Inbox` GenServer.
- **Durability at one boundary, not everywhere.** Persist exactly two things: open
  decision points (the pending-reply registry) and undelivered notifications. ETS backed
  by DETS is the minimal option; **Mnesia or SQLite/Postgres via Ecto is the honest
  recommendation** since these records must survive VM restarts and you want queries
  ("what's still open?"). `:persistent_term` is wrong here — it's optimized for
  rarely-written read-mostly globals, not a queue. This one table replaces the queue file,
  the relay directory, the lock, and firstmate's cursor+journal pair: a decision row is
  written before notification (WAL ordering for free from the DB), marked delivered, and
  marked resolved with the reply — three states, one schema.
- **Replies correlate by construction.** The human answers *a decision ID*
  (`reply <id> "..."` in whatever CLI/TUI/LiveView front end), and the Inbox routes it to
  the owning session process. Two concurrent questions on one branch — the exact known gap
  in the dotfiles system — become two rows with two IDs; misdirection is structurally
  impossible rather than merely unlikely.
- **Escalation is a timer.** On creating a decision point, `Process.send_after(self(),
  {:reply_overdue, id}, grace_ms)`; on `:reply_overdue` for a still-open ID, re-notify
  once, then escalate (firstmate's `awaiting_report → recovery → escalated` ladder,
  ~15 lines). A crashed session GenServer restarts, reloads its open decisions from the
  DB, and re-arms timers — supervision replaces firstmate's `mail_heal()`.
- **Fan-out is `Phoenix.PubSub`** if more than one surface should see notifications
  (terminal + phone + LiveView dashboard): sessions broadcast on
  `"decisions:<branch>"`; each surface subscribes. The dotfiles system's hardest
  constraint — a one-line notification squeezed into a TUI prompt box — becomes just one
  subscriber among several.
- **What stays hard:** the human edge. OTP correlates processes to processes; a person in
  a terminal is not a process. The delivery-to-a-busy-human problem (retries, "surface it
  again on session start") doesn't vanish — it moves into one subscriber module, where
  Step Functions' `HeartbeatSeconds` idea (a deadline that *fails loudly* instead of
  waiting forever) is the pattern worth copying.

### The single most important takeaway

The bash system's known gap — no reply-to-request correlation — is the cheapest thing to
fix in Elixir because it is the thing OTP was built around: `GenServer.call`'s reply tag
*is* firstmate's `corr=` token, minted and matched by the runtime. Design the Elixir
version so every human decision is a first-class record with an ID from birth, keep
durability confined to one small table of open decisions and undelivered notifications,
and let processes, monitors, and timers replace every retry loop, lock file, and cursor in
both bash systems.

---

## Source list

- This repo: `bin/herdr-worktree-wake.sh`, `claude/hooks/herdr-worktree-notify.sh`,
  `claude/hooks/herdr-worktree-resume.sh`, `claude/CLAUDE.md`,
  `claude/skills/spawn-worktree/SKILL.md`, `claude/skills/send-to-worktree/SKILL.md`,
  `tests/herdr-worktree-wake.test.sh`, `tests/herdr-worktree-notify-hook.test.sh`
- firstmate: raw.githubusercontent.com/kunchenguid/firstmate/main/bin/{fm-mail.sh, fm-send.sh, fm-pending-reply-lib.sh, fm-procevent-remote-reply.sh}
- Erlang/OTP: https://www.erlang.org/doc/apps/stdlib/gen_server
- AWS Step Functions: https://docs.aws.amazon.com/step-functions/latest/dg/connect-to-resource.html
- RabbitMQ: https://www.rabbitmq.com/tutorials/tutorial-six-python
- The "no correlation ID" gap in the dotfiles system: prior finding recorded in this
  repo's Claude memory (compared against kunchenguid/firstmate); restated here, not
  re-derived.

*Not included:* Temporal.io signals were a candidate fourth external system but were not
fetched/verified for this document, so they are omitted rather than described secondhand.
