# 04 — Whiska installs /whiska-reply and /whiska-close (ADR-0022)

Status: ready-for-agent
Repo: whiska (re-file there)
Blocked by: none.

ADR-0022 splits commands into "typed by you before a session exists" and "used by your
session once one is running", and puts `reply` in the second group. `Whiska.Install`
installs only `/whiska-questions`. The delivered line ends with `answer: whiska reply 12
"..."`, so today the main session composes the bash itself, which is the exact failure
mode ADR-0022 names.

Add to `@skills`:

- `/whiska-reply <id> <answer>`: runs `whiska reply <id> "<answer>"` with the person's
  words verbatim, then shows what it printed. It never invents the answer: if the person
  has not stated one, it asks. (This restates ADR-0017's main-session rule from the
  command side.)
- `/whiska-close <id>`: runs `whiska close <id>`.

`whiska init` writes them; `whiska doctor` already probes skills or should gain the line.

Once this exists, dotfiles' `spawn-worktree` never has to mention how to answer.

## Comments
