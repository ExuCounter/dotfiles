process.env.TZ = "UTC";
import { test } from "node:test";
import assert from "node:assert/strict";
import { timeLeft, level, pace, ago } from "../lib/format.js";
import { tokens } from "../lib/format.js";

const NOW = Date.UTC(2026, 10, 4, 8, 0, 0) / 1000; // Wed 2026-11-04 08:00 UTC

test("timeLeft", () => {
  assert.equal(timeLeft(38 * 60), "38m");
  assert.equal(timeLeft(4 * 3600 + 600), "4h 10m");
  assert.equal(timeLeft(2 * 86400 + 6 * 3600), "2d 6h");
  assert.equal(timeLeft(20), "<1m");
  assert.equal(timeLeft(-5), "<1m");
});

test("level thresholds", () => {
  assert.equal(level(69), "ok");
  assert.equal(level(70), "warn");
  assert.equal(level(89), "warn");
  assert.equal(level(90), "hot");
});

test("pace: weekly 50% with 2d 10h left → elapsed ≈ 0.6548, under", () => {
  const p = pace({ percent: 50, resetsAt: NOW + 58 * 3600, durationSec: 604800 }, NOW);
  assert.ok(Math.abs(p.elapsed - 0.6548) < 0.001, String(p.elapsed));
  assert.equal(p.verdict, "under");
});

test("pace: weekly 80% with 5d left → ahead; 35% at 2/7 → on pace", () => {
  assert.equal(pace({ percent: 80, resetsAt: NOW + 5 * 86400, durationSec: 604800 }, NOW).verdict, "ahead");
  assert.equal(pace({ percent: 35, resetsAt: NOW + 5 * 86400, durationSec: 604800 }, NOW).verdict, "on pace");
});

test("pace: unknown duration or reset → null", () => {
  assert.equal(pace({ percent: 5, resetsAt: null, durationSec: 604800 }, NOW), null);
  assert.equal(pace({ percent: 5, resetsAt: NOW + 10, durationSec: null }, NOW), null);
});

test("ago", () => {
  assert.equal(ago(NOW - 30, NOW), "just now");
  assert.equal(ago(NOW - 5 * 60, NOW), "5 min ago");
  assert.equal(ago(NOW - 3 * 3600, NOW), "3 h ago");
  assert.equal(ago(NOW - 2 * 86400, NOW), "2 d ago");
});

test("tokens: rounded for reading", () => {
  assert.equal(tokens(0), "0");
  assert.equal(tokens(999), "999");
  assert.equal(tokens(1500), "2k");
  assert.equal(tokens(190432), "190k");
  assert.equal(tokens(1000000), "1M");
  assert.equal(tokens(1250000), "1.3M");
});
