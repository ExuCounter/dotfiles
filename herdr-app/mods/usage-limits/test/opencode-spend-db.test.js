import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { MOD } from "./_util.js";

const today = new Date(); today.setHours(0, 0, 0, 0);
const before = new Date(today); before.setDate(before.getDate() - 6);
const t = today.getTime(); const week = before.getTime();
const q = (v) => `'${String(v).replaceAll("'", "''")}'`;
function fixture(storage, { empty = false, both = false } = {}) {
  const home = mkdtempSync(join(tmpdir(), "opencode-spend-db-"));
  const db = join(home, "opencode.db");
  const statements = [];
  for (const format of both ? ["v1", "v2"] : [storage]) {
    const sessions = format === "v1" ? "session" : "session_v2";
    const messages = format === "v1" ? "message" : "session_message";
    statements.push(`create table ${sessions}(id text, time_updated integer); create table ${messages}(id text, session_id text, time_created integer, data text${format === "v2" ? ",type text" : ""});`);
    statements.push(`insert into ${sessions} values ('own',${t + (format === "v2" ? 1 : 0)});`);
    if (!empty) for (const [i, at, input] of [[0, week - 1, 9000], [1, week, 100], [2, t, format === "v2" && both ? 300 : 200], [3, t + 86400000, 9999]]) {
      const data = { role: "assistant", tokens: { input, output: 10, reasoning: 5, cache: { read: 20, write: 2 } } };
      statements.push(`insert into ${messages} values ('m${i}','own',${at},${q(JSON.stringify(data))}${format === "v2" ? ",'assistant'" : ""});`);
    }
  }
  const r = spawnSync("sqlite3", [db], { input: statements.join("\n"), encoding: "utf8" });
  assert.equal(r.status, 0, r.stderr);
  return { home, db };
}
function run(h, extra = {}) {
  const env = { ...process.env, HOME: h.home, PATH: "/usr/bin:/bin:/usr/sbin:/sbin", HERDR_USAGE_OPENCODE_DB: h.db, ...extra };
  delete env.HERDR_USAGE_OPENCODE_BIN;
  return spawnSync("sh", [join(MOD, "helpers/opencode-spend.sh")], { env, encoding: "utf8", timeout: 10000 });
}
const counts = (input, n) => ({ input, output: 10 * n, reasoning: 5 * n, cache: { read: 20 * n, write: 2 * n } });
for (const storage of ["v1", "v2"]) {
  test(`OpenCode ${storage}: GUI PATH without CLI reads numeric day/week statistics from DB`, () => {
    const h = fixture(storage); const before = readFileSync(h.db);
    const r = run(h);
    assert.equal(r.status, 0, r.stderr);
    assert.deepEqual(JSON.parse(r.stdout), { today: { tokens: counts(200, 1) }, week: { tokens: counts(300, 2) } });
    assert.deepEqual(readFileSync(h.db), before);
  });
}
test("OpenCode DB: empty installed database is zero usage, not 'not installed'", () => {
  const r = run(fixture("v1", { empty: true }));
  assert.equal(r.status, 0, r.stderr);
  assert.deepEqual(JSON.parse(r.stdout), { today: { tokens: counts(0, 0) }, week: { tokens: counts(0, 0) } });
});
test("OpenCode DB: migration representations are counted once", () => {
  const r = run(fixture("v1", { both: true }));
  assert.equal(r.status, 0, r.stderr);
  assert.deepEqual(JSON.parse(r.stdout), { today: { tokens: counts(300, 1) }, week: { tokens: counts(400, 2) } });
});
test("OpenCode DB: unavailable reader reports failure, not missing installation", () => {
  const r = run(fixture("v1"), { HERDR_USAGE_SQLITE_BIN: "/nonexistent/sqlite3" });
  assert.deepEqual([r.status, r.stdout], [1, ""]);
});
