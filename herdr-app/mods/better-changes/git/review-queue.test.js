import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { reviewQueue, toThread, displayName, isBot, excerpt, threadResults } from "./review-queue.js";

const ME = 1;
const note = (authorId, at, extra = {}) => ({ authorId, bot: false, at, body: "", ...extra });
const bot = (at) => note(99, at, { bot: true });
const thread = (id, notes, extra = {}) => ({ id, resolvable: true, resolved: false, notes, ...extra });

test("an open thread is in the queue whoever started it", () => {
  const queue = reviewQueue([thread("bot", [bot(1)]), thread("person", [note(2, 2)])], ME);
  assert.deepEqual(queue.map((item) => item.id), ["bot", "person"]);
});

test("a resolved thread is not in the queue", () => {
  assert.deepEqual(reviewQueue([thread("done", [bot(1)], { resolved: true })], ME), []);
});

test("a bot's plain comment is not in the queue", () => {
  assert.deepEqual(reviewQueue([thread("summary", [bot(1)], { resolvable: false })], ME), []);
});

test("a person's plain comment is in the queue until I answer it", () => {
  const asked = thread("asked", [note(2, 1)], { resolvable: false });
  const answered = thread("answered", [note(2, 1), note(ME, 2)], { resolvable: false });
  assert.deepEqual(reviewQueue([asked, answered], ME).map((item) => item.id), ["asked"]);
});

test("my own plain comment is not in the queue", () => {
  assert.deepEqual(reviewQueue([thread("mine", [note(ME, 1)], { resolvable: false })], ME), []);
});

test("a thread waits on whoever didn't write its last note", () => {
  const queue = reviewQueue([thread("theirs", [bot(1)]), thread("answered", [bot(2), note(ME, 3), bot(4), note(ME, 5)])], ME);
  assert.deepEqual(
    queue.map((item) => [item.id, item.waitingOn]),
    [
      ["theirs", "me"],
      ["answered", "them"],
    ],
  );
});

test("threads waiting on me come first, each side oldest first", () => {
  const queue = reviewQueue(
    [
      thread("answered-old", [bot(1), note(ME, 9)]),
      thread("open-new", [bot(5)]),
      thread("answered-new", [bot(3), note(ME, 4)]),
      thread("open-old", [bot(2)]),
    ],
    ME,
  );
  assert.deepEqual(queue.map((item) => item.id), ["open-old", "open-new", "answered-old", "answered-new"]);
});

test("a name GitLab masks falls back to the username", () => {
  assert.equal(displayName({ name: "****", username: "group_1000000_bot_60d7" }), "@group_1000000_bot_60d7");
  assert.equal(displayName({ name: "", username: "vova" }), "@vova");
  assert.equal(displayName({ name: "Vova Potiichuk", username: "vova" }), "Vova Potiichuk");
});

test("bot accounts are told apart by username", () => {
  assert.equal(isBot({ username: "group_1000000_bot_00000000000000000000000000000000" }), true);
  assert.equal(isBot({ username: "renovate-bot" }), true);
  assert.equal(isBot({ username: "vova.potiichuk" }), false);
  assert.equal(isBot({ username: "abbott" }), false);
});

test("a discussion becomes a thread whose notes say who wrote them", () => {
  const discussion = {
    id: "d1",
    notes: [
      { system: true, body: "added 1 commit", author: { id: 1, username: "vova" } },
      {
        body: "finding",
        resolvable: true,
        resolved: false,
        created_at: "2026-11-16T16:38:13.983Z",
        position: { new_path: "a.ex", new_line: 13, old_path: "a.ex", old_line: null },
        author: { id: 99, name: "****", username: "group_1_bot_x" },
      },
    ],
  };
  assert.deepEqual(toThread(discussion), {
    id: "d1",
    path: "a.ex",
    line: 13,
    side: "new",
    resolvable: true,
    resolved: false,
    notes: [
      { authorId: 99, author: "group_1_bot_x", name: "@group_1_bot_x", bot: true, body: "finding", at: Date.parse("2026-11-16T16:38:13.983Z") },
    ],
  });
});

test("a discussion of only system notes is no thread", () => {
  assert.equal(toThread({ id: "d2", notes: [{ system: true, body: "changed the description" }] }), null);
});

test("a thread on a whole file has a path and no line", () => {
  const discussion = {
    id: "d3",
    notes: [
      {
        body: "file-wide",
        resolvable: true,
        created_at: "2026-11-16T17:39:42.818Z",
        position: { position_type: "file", new_path: "a.test.tsx", old_path: "a.test.tsx" },
        author: { id: 99, username: "group_1_bot_x" },
      },
    ],
  };
  assert.deepEqual([toThread(discussion).path, toThread(discussion).line], ["a.test.tsx", null]);
});

test("better-sidebar's copy is the same file", () => {
  const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
  assert.equal(read("../../better-sidebar/git/review-queue.js"), read("./review-queue.js"));
});

test("a short note is shown whole", () => {
  assert.deepEqual(excerpt("one\ntwo", 3), { text: "one\ntwo", clipped: false });
});

test("a long note keeps its first lines", () => {
  assert.deepEqual(excerpt("1\n2\n3\n4", 2), { text: "1\n2", clipped: true });
});

test("a note cut inside a code block closes the block", () => {
  assert.deepEqual(excerpt("intro\n```js\na\nb\n```", 3), { text: "intro\n```js\na\n```", clipped: true });
});

test("blank lines and bot bookkeeping don't count", () => {
  assert.deepEqual(excerpt("<!-- meta -->\n\n**Title**\n\nbody", 2), { text: "**Title**\n\nbody", clipped: false });
});

test("a dismissed comment leaves the queue until someone writes on it again", () => {
  const comment = (notes) => thread("c", notes, { resolvable: false });
  assert.deepEqual(reviewQueue([comment([note(2, 5)])], ME, { c: 5 }), []);
  assert.deepEqual(reviewQueue([comment([note(2, 5), note(3, 9)])], ME, { c: 5 }).map((item) => item.id), ["c"]);
});

test("CodeRabbit's notes go by its name, not its masked bot account", () => {
  const discussion = {
    id: "d4",
    notes: [
      {
        body: "<!-- coderabbit-ai-generated:v1 -->\nfinding",
        resolvable: true,
        created_at: "2026-11-16T16:38:13.983Z",
        author: { id: 99, name: "****", username: "group_1000000_bot_00000000000000000000000000000000" },
      },
    ],
  };
  assert.equal(toThread(discussion).notes[0].name, "CodeRabbit");
});

test("an agent's latest note on each thread is its result", () => {
  const text = [
    JSON.stringify({ thread: "a", kind: "not-fixed", reason: "unclear", at: 1 }),
    JSON.stringify({ thread: "a", kind: "fixed", commit: "abc123", at: 2 }),
    "not json",
    JSON.stringify({ thread: "b", kind: "already-fixed", commit: "def456", at: 3 }),
    "",
  ].join("\n");
  assert.deepEqual(threadResults(text), {
    a: { kind: "fixed", commit: "abc123", reason: undefined, at: 2 },
    b: { kind: "already-fixed", commit: "def456", reason: undefined, at: 3 },
  });
});
