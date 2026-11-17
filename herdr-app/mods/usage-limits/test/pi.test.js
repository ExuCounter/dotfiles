import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import pi from "../providers/pi.js";
import { HERE } from "./_util.js";

const sec = (d) => Math.floor(d.getTime() / 1000);
const line = (d, n) => `${d.toISOString()} ${n}`;

test("descriptor", () => {
  assert.deepEqual(
    { id: pi.id, name: pi.name, icon: pi.icon, kind: pi.kind, helper: pi.helper },
    { id: "pi", name: "Pi", icon: "icons/pi.svg", kind: "spend", helper: "helpers/pi-spend.sh" },
  );
});

test("today since local midnight, week since local midnight six days before", () => {
  // Local times, so this holds in any time zone.
  const now = new Date(2026, 10, 12, 12);
  const text = [
    line(new Date(2026, 10, 12, 0, 30), 100),
    line(new Date(2026, 10, 11, 23, 30), 20),
    line(new Date(2026, 10, 6, 12), 3),
    line(new Date(2026, 10, 5, 12), 4000),
  ].join("\n") + "\n";
  const r = pi.parse(text, sec(now));
  assert.equal(r.status, "ok");
  assert.deepEqual(r.spend, { today: 100, week: 123 });
  assert.deepEqual(r.windows, []);
  assert.equal(r.observedAt, sec(now));
});

test("across a month boundary the week still starts six local days back", () => {
  const now = new Date(2026, 11, 3, 9);
  const text = [line(new Date(2026, 10, 27, 0, 1), 5), line(new Date(2026, 10, 26, 23, 59), 70)].join("\n");
  assert.deepEqual(pi.parse(text, sec(now)).spend, { today: 0, week: 5 });
});

test("no replies → ok with zeros", () => {
  const r = pi.parse("", sec(new Date(2026, 10, 12, 12)));
  assert.equal(r.status, "ok");
  assert.deepEqual(r.spend, { today: 0, week: 0 });
});

test("malformed lines are skipped", () => {
  const text = readFileSync(join(HERE, "fixtures", "pi-spend.txt"), "utf8");
  // 12:20 UTC: the 12:19 line is today in every zone, 11-10 08:00 is never today, 11-01 is never in the week.
  const r = pi.parse(text, Date.UTC(2026, 10, 12, 12, 20) / 1000);
  assert.equal(r.status, "ok");
  assert.deepEqual(r.spend, { today: 1200, week: 4200 });
});
