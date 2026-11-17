import { test } from "node:test";
import assert from "node:assert/strict";
import { codexBinding, parseSessionChoices, sessionReadResult } from "../lib/session-binding.js";

const id = "01a1d088-0c3f-7b53-ba61-390c96962e3e";
const own = { term: { pid: 123, id, identity: "process start" } };

test("session binding: selections belong to the terminal process, not just its address", () => {
  assert.deepEqual(codexBinding(own, "term", 123), { id, identity: "process start", manual: true });
  assert.equal(codexBinding(own, "term", 456), null);
  assert.equal(codexBinding(own, "other", 123), null);
  assert.equal(codexBinding({ term: { ...own.term, id: "../../file" } }, "term", 123), null);
});

test("session binding: uses Patchbay's confirmed choice only for this process and boot", () => {
  const patchbay = { term: { pid: 123, id, boot: "boot-1", manual: true } };
  assert.deepEqual(codexBinding({}, "term", 123, patchbay, "boot-1"), { id, identity: "", manual: false });
  assert.equal(codexBinding({}, "term", 456, patchbay, "boot-1"), null);
  assert.equal(codexBinding({}, "term", 123, patchbay, "boot-2"), null);
  assert.equal(codexBinding({}, "term", 123, patchbay), null);
});

test("session binding: a process-bound Patchbay choice survives interface reloads", () => {
  const patchbay = { term: { pid: 123, id, boot: "old-boot", manual: true, startedAt: 1794499935000 } };
  assert.deepEqual(codexBinding({}, "term", 123, patchbay, "new-boot"), { id, identity: "started:1794499935000", manual: false });
  assert.equal(codexBinding({}, "term", 456, patchbay, "new-boot"), null);
});

test("session choices: filters invalid rows and refuses another process's response", () => {
  const data = { pid: 123, identity: "process start", choices: [{ id, title: "Session" }, { id: "../secret", title: "Bad" }] };
  assert.deepEqual(parseSessionChoices(JSON.stringify(data), 123), { ...data, choices: [data.choices[0]] });
  assert.equal(parseSessionChoices(JSON.stringify(data), 456), null);
  assert.equal(parseSessionChoices("garbage", 123), null);
  assert.equal(parseSessionChoices(JSON.stringify({ ...data, identity: "" }), 123), null);
});

test("session result: a selected session retains its change control while usage is unavailable", () => {
  const result = sessionReadResult({ code: 1, stdout: "" }, "codex", { manual: true }, 123, "project");
  assert.deepEqual(result, { session: null, choices: null, manual: true });
});
