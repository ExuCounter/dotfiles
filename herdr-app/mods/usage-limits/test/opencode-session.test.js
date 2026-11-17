import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { MOD } from "./_util.js";

const START = 1793613600;
const DIR = "/home/demo/it's a project";
const q = (v) => typeof v === "number" ? String(v) : `'${String(v).replaceAll("'", "''")}'`;
const tokens = { input: 1000, output: 20, reasoning: 30, cache: { read: 400, write: 50 } };
const rows = [{ role: "user" }, { role: "assistant", tokens, model: "demo-model" }, { role: "user" }];
const schemas = {
  v1: `create table session(id text, parent_id text, directory text, time_updated integer);
    create table message(id text, session_id text, time_created integer, time_updated integer, data text);
    create table part(id text, message_id text, session_id text, time_created integer, time_updated integer, data text);`,
  v2: `create table session_v2(id text, parent_id text, directory text, time_updated integer, model text);
    create table session_message(id text, session_id text, type text, seq integer, data text);`,
};

function makeDb(sessions, extra = "") {
  const db = join(mkdtempSync(join(tmpdir(), "opencode-stores-")), "opencode.db");
  let sql = [...new Set(sessions.map((s) => s.storage))].map((v) => schemas[v]).join("\n") + extra;
  for (const s of sessions) {
    const time = (START + (s.updated ?? 60)) * 1000;
    const values = [s.id ?? "own", s.parent ? q(s.parent) : "NULL", q(s.dir ?? DIR), time];
    values[0] = q(values[0]);
    if (s.storage === "v2") values.push(q(JSON.stringify({ id: s.model ?? "demo-model" })));
    sql += `insert into ${s.storage === "v1" ? "session" : "session_v2"} values (${values.join(",")});\n`;
    (s.rows ?? rows).forEach((m, i) => {
      const id = `${s.id ?? "own"}-${s.storage}-${i}`;
      const data = s.storage === "v1" ? { role: m.role, tokens: m.tokens, modelID: m.model,
        summary: m.compaction || undefined, finish: m.compaction ? "stop" : undefined,
        error: m.failed ? { name: "Aborted" } : undefined, parentID: m.parentID } :
        { tokens: m.tokens, status: m.compaction ? (m.failed ? "failed" : "completed") : undefined };
      if (s.storage === "v1") {
        sql += `insert into message values (${q(id)},${q(s.id ?? "own")},${time + i},${time + i},${q(JSON.stringify(data))});\n`;
        const part = m.request ? { type: "compaction" } : { type: "text", text: "private message text", synthetic: Boolean(m.synthetic) };
        sql += `insert into part values (${q(id + "-part")},${q(id)},${q(s.id ?? "own")},${time + i},${time + i},${q(JSON.stringify(part))});\n`;
      } else sql += `insert into session_message values (${q(id)},${q(s.id ?? "own")},${q(m.compaction ? "compaction" : m.role)},${i + 1},${q(JSON.stringify(data))});\n`;
    });
  }
  const r = spawnSync("sqlite3", [db], { input: sql, encoding: "utf8" });
  assert.equal(r.status, 0, r.stderr);
  return db;
}

function run(db, extra = {}) {
  return spawnSync("sh", [join(MOD, "helpers/session.sh"), "opencode", "4242"], {
    env: { ...process.env, HERDR_USAGE_OPENCODE_DB: db, HERDR_USAGE_PROC_CWD: DIR,
      HERDR_USAGE_PROC_START: String(START), HERDR_USAGE_PROC_PEERS: "1", ...extra }, encoding: "utf8", timeout: 10000,
  });
}
const expected = "tokens=1500 calls=2 compactions=0 model=demo-model\n";

for (const storage of ["v1", "v2"]) {
  test(`OpenCode ${storage}: identical statistics and read-only access`, () => {
    const db = makeDb([{ storage }]); const before = readFileSync(db);
    const r = run(db);
    assert.deepEqual([r.status, r.stdout], [0, expected]);
    assert.deepEqual(readFileSync(db), before);
    assert.doesNotMatch(r.stdout, /private|v1|v2/);
  });
  test(`OpenCode ${storage}: unfinished replies retain last measured context`, () => {
    const r = run(makeDb([{ storage, rows: [...rows, { role: "assistant", tokens: { input: 0, output: 0 } }] }]));
    assert.equal(r.stdout, expected);
  });
  test(`OpenCode ${storage}: another folder, subagents and old sessions are excluded`, () => {
    assert.equal(run(makeDb([{ storage }, { storage, id: "child", parent: "own" }, { storage, id: "elsewhere", dir: "/elsewhere" }, { storage, id: "old", updated: -600 }])).stdout, expected);
  });
}

test("OpenCode legacy: an empty migration table does not hide the real messages", () => {
  const db = makeDb([{ storage: "v1" }], "create table session_message(id text, session_id text, type text, seq integer, data text);");
  assert.equal(run(db).stdout, expected);
});

test("OpenCode legacy: successful compaction hides old context; the next reply restores it", () => {
  const compacted = [...rows, { role: "user", request: true }, { role: "assistant", compaction: true, tokens, model: "summary-model", parentID: "own-v1-3" }];
  const r = run(makeDb([{ storage: "v1", rows: compacted }]));
  assert.deepEqual([r.status, r.stdout], [1, ""]);
  const next = [...compacted, { role: "user", synthetic: true }, { role: "assistant", tokens: { input: 2100, output: 40 }, model: "new-model" }];
  assert.equal(run(makeDb([{ storage: "v1", rows: next }])).stdout, "tokens=2140 calls=2 compactions=1 model=new-model\n");
});

test("OpenCode legacy: failed compaction does not change context or inflate calls", () => {
  const failed = [...rows, { role: "user", request: true }, { role: "assistant", compaction: true, failed: true, tokens, parentID: "own-v1-3" }];
  assert.equal(run(makeDb([{ storage: "v1", rows: failed }])).stdout, expected);
});

test("OpenCode mixed: distinct eligible sessions across formats remain ambiguous", () => {
  const r = run(makeDb([{ storage: "v1", id: "first" }, { storage: "v2", id: "second" }]));
  assert.deepEqual([r.status, r.stdout], [1, ""]);
});

test("OpenCode mixed: a migrated ID is one session and uses its newer representation", () => {
  const db = makeDb([{ storage: "v1", updated: 10 }, { storage: "v2", updated: 60, rows: [{ role: "user" }, { role: "assistant", tokens: { input: 700, output: 10 } }] }]);
  assert.equal(run(db).stdout, "tokens=710 calls=1 compactions=0 model=demo-model\n");
});

test("OpenCode mixed: an empty migration row cannot shadow populated legacy messages", () => {
  const db = makeDb([{ storage: "v1" }, { storage: "v2", updated: 120, rows: [] }]);
  assert.equal(run(db).stdout, expected);
});
