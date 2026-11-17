import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { MOD } from "./_util.js";

const ID = "01a1d088-0c3f-7b53-ba61-390c96962e3e";
const OTHER = "01a1d086-a915-7690-a80d-b5ab2622a215";
const event = (type, fields = {}) => ({ type: "event_msg", payload: { type, ...fields } });
const usage = (n) => event("token_count", { info: { last_token_usage: { total_tokens: n }, model_context_window: 475000 } });

function setup(records, { owner = 123, lock = false } = {}) {
  const home = mkdtempSync(join(tmpdir(), "codex-session-"));
  const day = join(home, "sessions", "2026", "11", "12");
  const bin = join(home, "bin");
  mkdirSync(day, { recursive: true }); mkdirSync(bin);
  const file = join(day, `rollout-demo-${ID}.jsonl`);
  writeFileSync(file, records.map(JSON.stringify).join("\n") + "\n");
  const paths = lock ? [join(home, "thread-writer-locks", `${ID}.lock`)] : [file];
  writeFileSync(join(bin, "lsof"), `#!/bin/sh\nif [ "$4" = cwd ] && [ "$7" = -Fn ]; then printf 'p123\\nn/demo/project\\n'; exit; fi\n[ "$4" = ${owner} ] || exit 1\nprintf '%s\\n' ${paths.map((p) => `'n${p}'`).join(" ")}\n`, { mode: 0o755 });
  writeFileSync(join(bin, "pgrep"), '#!/bin/sh\necho 456\n', { mode: 0o755 });
  const env = { ...process.env, CODEX_HOME: home, CODEX_SQLITE_HOME: home, PATH: `${bin}:${process.env.PATH}`, HERDR_USAGE_PROC_CWD: "/demo/project", HERDR_USAGE_PROC_IDENTITY: "Thu Nov 12 19:12:15 2026" };
  return { home, file, env };
}
function run(h, ...binding) {
  return spawnSync("sh", [join(MOD, "helpers/session.sh"), "codex", "123", ...binding], { env: h.env, encoding: "utf8", timeout: 10000 });
}
function index(h) {
  const r = spawnSync("python3", ["-I", "-c", `import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
c.execute("CREATE TABLE threads (id TEXT, rollout_path TEXT, cwd TEXT, title TEXT, archived INTEGER, updated_at INTEGER, source TEXT DEFAULT 'cli')")
c.execute('INSERT INTO threads (id,rollout_path,cwd,title,archived,updated_at) VALUES (?,?,?,?,0,1)',(sys.argv[2],sys.argv[3],'/demo/project','My session'))
c.commit()`, join(h.home, "state_5.sqlite"), ID, h.file], { encoding: "utf8" });
  assert.equal(r.status, 0, r.stderr);
}

test("Codex embedded server: reads the terminal process's own rollout, including spaced JSON", () => {
  const h = setup([event("task_started"), usage(12345)]);
  const r = run(h);
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.stdout, "tokens=12345 window=475000 calls=1 compactions=0\n");
});

test("Codex: a writer-lock identifies the exact session even when the rollout is closed", () => {
  const h = setup([event("task_started"), usage(222)], { lock: true }); index(h);
  assert.equal(run(h).stdout, "tokens=222 window=475000 calls=1 compactions=0\n");
});

test("Codex: counts compacted records once, ignores forged nested events and unfinished lines", () => {
  const h = setup([event("task_started"), usage(900), { type: "compacted", payload: { message: "private summary" } }, event("context_compacted"), usage(120), event("turn_started"), { type: "response_item", payload: { type: "message", content: [{ type: "compacted" }, event("task_started"), usage(999)] } }, usage(150)]);
  writeFileSync(h.file, '{"type":"event_msg","payload":', { flag: "a" });
  assert.equal(run(h).stdout, "tokens=150 window=475000 calls=2 compactions=1\n");
});

test("Codex: drops pre-compaction context until fresh token usage arrives", () => {
  const h = setup([event("task_started"), usage(900), { type: "compacted", payload: {} }]);
  const r = run(h);
  assert.equal(r.status, 1);
  assert.equal(r.stdout, "");
});

test("Codex daemon: offers choices instead of taking another process's newest session", () => {
  const h = setup([event("task_started"), usage(333)], { owner: 999 }); index(h);
  const r = run(h);
  assert.equal(r.status, 2, r.stderr);
  assert.deepEqual(JSON.parse(r.stdout), { pid: 123, identity: h.env.HERDR_USAGE_PROC_IDENTITY, choices: [{ id: ID, title: "My session" }] });
});

test("Codex daemon: an explicit choice reads the selected session and expires on PID reuse", () => {
  const h = setup([event("task_started"), usage(333)], { owner: 999 }); index(h);
  assert.equal(run(h, ID, h.env.HERDR_USAGE_PROC_IDENTITY).stdout, "tokens=333 window=475000 calls=1 compactions=0\n");
  assert.equal(run(h, ID, "previous process").status, 2);
  assert.equal(run(h, OTHER, h.env.HERDR_USAGE_PROC_IDENTITY).status, 2);
  assert.equal(run(h, "../../secret", h.env.HERDR_USAGE_PROC_IDENTITY).status, 2);
});

test("Codex daemon: a confirmed process start keeps idle session statistics across UI reloads", () => {
  const h = setup([event("task_started"), usage(333)], { owner: 999 }); index(h);
  const r = spawnSync("python3", ["-I", "-c", "from datetime import datetime;import sys;print(int(datetime.strptime(sys.argv[1],'%a %b %d %H:%M:%S %Y').timestamp()*1000))", h.env.HERDR_USAGE_PROC_IDENTITY], { encoding: "utf8" });
  assert.equal(r.status, 0, r.stderr);
  assert.equal(run(h, ID, `started:${r.stdout.trim()}`).stdout, "tokens=333 window=475000 calls=1 compactions=0\n");
  assert.equal(run(h, ID, "started:1000").status, 2, "a reused PID cannot inherit the old session");
});

test("Codex: inherited CODEX_THREAD_ID never selects the caller's session", () => {
  const h = setup([usage(333)], { owner: 999 }); index(h); h.env.CODEX_THREAD_ID = ID;
  assert.equal(run(h).status, 2);
});

test("Codex daemon: asks lsof for machine-readable cwd fields", () => {
  const h = setup([usage(333)], { owner: 999 }); index(h);
  delete h.env.HERDR_USAGE_PROC_CWD;
  assert.equal(run(h).status, 2);
});

test("Codex: ambiguous open files offer a choice instead of following another conversation's writes", () => {
  const h = setup([usage(333)]); index(h);
  const other = join(h.home, "sessions", `rollout-other-${OTHER}.jsonl`);
  writeFileSync(other, JSON.stringify(usage(999)) + "\n");
  writeFileSync(join(h.home, "bin", "lsof"), `#!/bin/sh\n[ "$4" = 123 ] || exit 1\nprintf '%s\\n' 'n${h.file}' 'n${other}'\n`, { mode: 0o755 });
  assert.equal(run(h).status, 2);
  assert.equal(run(h, ID, h.env.HERDR_USAGE_PROC_IDENTITY).stdout, "tokens=333 window=475000 calls=0 compactions=0\n");
});

test("Codex: a new writer-lock with no published rollout cannot fall back to a previous manual choice", () => {
  const h = setup([usage(333)], { lock: true }); index(h);
  const r = spawnSync("python3", ["-I", "-c", "import sqlite3,sys;c=sqlite3.connect(sys.argv[1]);c.execute('UPDATE threads SET id=?',(sys.argv[2],));c.commit()", join(h.home, "state_5.sqlite"), OTHER], { encoding: "utf8" });
  assert.equal(r.status, 0, r.stderr);
  const other = join(h.home, "sessions", `rollout-old-${OTHER}.jsonl`);
  writeFileSync(other, JSON.stringify(usage(999)) + "\n");
  const update = spawnSync("python3", ["-I", "-c", "import sqlite3,sys;c=sqlite3.connect(sys.argv[1]);c.execute('UPDATE threads SET rollout_path=?',(sys.argv[2],));c.commit()", join(h.home, "state_5.sqlite"), other], { encoding: "utf8" });
  assert.equal(update.status, 0, update.stderr);
  const result = run(h, OTHER, h.env.HERDR_USAGE_PROC_IDENTITY);
  assert.deepEqual([result.status, result.stdout], [1, ""]);
});

test("Codex: subagents' writer-locks and rollouts do not make their parent session ambiguous", () => {
  const h = setup([usage(333)], { lock: true }); index(h);
  const child = join(h.home, "sessions", `rollout-child-${OTHER}.jsonl`);
  const source = { subagent: { thread_spawn: { parent_thread_id: ID, depth: 1 } } };
  writeFileSync(child, [JSON.stringify({ type: "session_meta", payload: { id: OTHER, source } }), JSON.stringify(usage(999))].join("\n"));
  const r = spawnSync("python3", ["-I", "-c", "import sqlite3,sys;c=sqlite3.connect(sys.argv[1]);c.execute('INSERT INTO threads VALUES (?,?,?,?,0,2,?)',(sys.argv[2],sys.argv[3],'/demo/project','Child',sys.argv[4]));c.commit()", join(h.home, "state_5.sqlite"), OTHER, child, JSON.stringify(source)], { encoding: "utf8" });
  assert.equal(r.status, 0, r.stderr);
  writeFileSync(join(h.home, "bin", "lsof"), `#!/bin/sh\n[ "$4" = 123 ] || exit 1\nprintf '%s\\n' 'n${h.file}' 'n${child}' 'n${join(h.home, 'thread-writer-locks', `${ID}.lock`)}' 'n${join(h.home, 'thread-writer-locks', `${OTHER}.lock`)}'\n`, { mode: 0o755 });
  assert.equal(run(h).stdout, "tokens=333 window=475000 calls=0 compactions=0\n");
  unlinkSync(join(h.home, "state_5.sqlite"));
  assert.equal(run(h).stdout, "tokens=333 window=475000 calls=0 compactions=0\n", "session metadata also identifies the child when the index is unavailable");
});
