#!/usr/bin/env bash
# Claude Code's SessionStart, UserPromptSubmit, PreToolUse, Notification
# (permission_prompt), Stop and SessionEnd hook: the session's state for the
# Herdr app, which reads it only from OSC 7501 and Claude Code sends none.
#
# It writes the record to the pty of the claude process (hooks run with no
# controlling terminal, so /dev/tty fails) and sets the agents-ids labels
# agent.session, agent.app, agent.doing, agent.next and agent.needs with
# `hc label`. It speaks only for the terminal's own session: in an hc
# terminal, from the claude that is its foreground program, with the session
# id in agent.session. It never fails the turn.

[ -n "${HC_TERMINAL_ID:-}" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0
command -v hc >/dev/null 2>&1 || exit 0

HERDR_STATUS_INPUT="$(cat)" python3 - <<'PY' 2>/dev/null
import base64, json, os, re, subprocess, time

WIDTH = 40
SHELLS = {"sh", "bash", "zsh", "dash", "fish"}
term = os.environ["HC_TERMINAL_ID"]
dev_dir = os.environ.get("HERDR_STATUS_DEV_DIR", "/dev")


def run(*argv):
    return subprocess.run(argv, capture_output=True, text=True, timeout=5).stdout


def claude_process():
    """The nearest ancestor that is not a shell: (pid, tty)."""
    pid = os.getppid()
    for _ in range(10):
        ppid, tty, comm = run("ps", "-o", "ppid=,tty=,comm=", "-p", str(pid)).split(None, 2)
        if os.path.basename(comm.strip()).lstrip("-") not in SHELLS:
            return pid, tty
        pid = int(ppid)
    raise SystemExit(0)


def plain(line):
    line = re.sub(r"^(#+|>|[-*+]|\d+\.)\s+", "", line.strip())
    line = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", line)
    return re.sub(r"\*\*|__|`", "", line).strip()


def fit(line):
    return line[: WIDTH - 1] + "…" if len(line) > WIDTH else line


def first_plain(text):
    return next((p for p in map(plain, (text or "").split("\n")) if p), "")


def doing(name, given):
    """What a tool does, worded as Whiska's progress hook words it."""
    said = given.get("description")
    if name == "Bash":
        return said if isinstance(said, str) and said else "running " + given.get("command", "").split("\n")[0].strip()
    if name in ("Edit", "Write", "NotebookEdit") and "file_path" in given:
        return "editing " + os.path.basename(given["file_path"])
    if name == "Read" and "file_path" in given:
        return "reading " + os.path.basename(given["file_path"])
    if name in ("Grep", "Glob") and "pattern" in given:
        return "searching for " + given["pattern"]
    if name in ("Agent", "Task") and isinstance(said, str):
        return said
    if name == "Skill" and "skill" in given:
        return "/" + given["skill"]
    if name.startswith("mcp__"):
        return name.split("__")[-1]
    return name


def reply(message):
    """(state, line) for a finished turn: a question asks for you."""
    lines = [p for p in map(plain, (message or "").split("\n")) if p]
    if lines and lines[-1].endswith("?"):
        return "blocked:kind=question", "❓ " + lines[-1]
    return "done", lines[0] if lines else ""


hook = json.loads(os.environ["HERDR_STATUS_INPUT"])
event, session = hook.get("hook_event_name"), hook.get("session_id")
pid, tty = claude_process()
terminal = json.loads(run("hc", "get", term, "--json"))
if tty in ("", "??") or (terminal.get("foreground") or {}).get("pid") != pid:
    raise SystemExit(0)
labels = terminal.get("labels") or {}
if event != "SessionStart" and labels.get("agent.session") != session:
    raise SystemExit(0)

now = str(int(time.time()))
turn = ["agent.doing=", "agent.doing.since=", "agent.next=", "agent.needs="]
if event == "SessionStart":
    state, line, label = "idle", "", ["agent.session=" + session, "agent.app=claude"] + turn
elif event == "UserPromptSubmit":
    line = first_plain(hook.get("prompt"))
    state, label = "working", ["agent.doing=" + fit(line), "agent.doing.since=" + now, "agent.next=", "agent.needs="]
elif event == "PreToolUse":
    # Async, so it may land after the turn ended: then it leaves that be.
    if (terminal.get("status") or {}).get("state") != "working":
        raise SystemExit(0)
    line = doing(hook.get("tool_name", ""), hook.get("tool_input") or {})
    state, label = "working", ["agent.doing=" + fit(line), "agent.doing.since=" + now]
elif event == "Notification":
    line = first_plain(hook.get("message"))
    state, label = "blocked:kind=permission", ["agent.doing=" + fit(line), "agent.doing.since=" + now, "agent.needs=you"]
elif event == "Stop":
    state, line = reply(hook.get("last_assistant_message"))
    needs = "you" if state.startswith("blocked") else ""
    label = turn[:2] + ["agent.next=" + fit(line), "agent.needs=" + needs]
elif event == "SessionEnd":
    state, line, label = "clear", "", turn
else:
    raise SystemExit(0)

record = "state=" + state
if state != "clear":
    record += ":app=claude-code"
if line:
    record += ":msg=" + base64.b64encode(fit(line).encode()).decode()
with open(os.path.join(dev_dir, tty), "a") as pty:
    pty.write("\033]7501;" + record + "\033\\")
run("hc", "label", term, *label)
PY
exit 0
