// spaces-smart's own logic, kept out of main.js so each Herdr update's
// shipped main.js merges in with few conflicts. Pure: no herdr or gpui-kit
// imports, so node tests it (tests/spaces-smart.test.mjs).

// Spaces in sidebar order (`list`: ordered()'s rows, in the core's order).
// A repo with a worktree open is one group, at its first space's place: its
// main checkout leads it (`lead`) when open, the rest go beneath (`nested`).
// Every row of a group carries `group`: the repo's key and name, and whether
// its main checkout is open.
export function arrange(list) {
  const linked = new Set(list.filter((r) => r.g?.linked).map((r) => r.g.repo));
  const out = [];
  const placed = new Set();
  for (const r of list) {
    const key = r.g?.repo;
    if (!linked.has(key)) {
      out.push({ ...r, tree: null });
      continue;
    }
    if (placed.has(key)) continue;
    placed.add(key);
    const members = list.filter((k) => k.g?.repo === key);
    const lead = members.find((k) => !k.g.linked);
    const kids = members.filter((k) => k !== lead);
    const group = { key, name: r.g.name, open: Boolean(lead) };
    if (lead) out.push({ ...lead, tree: null, group, lead: true });
    for (const k of kids) out.push({ ...k, tree: null, group, nested: true });
  }
  return out;
}

// What the sidebar draws of `rows` (arrange()'s): a heading before a group
// whose main checkout isn't open, and a folded group (`folded`: repo keys)
// without its worktrees, but for the shown one.
export function fold(rows, folded) {
  const out = [];
  const headed = new Set();
  for (const r of rows) {
    const key = r.group?.key;
    const shut = folded.has(key);
    if (key && !headed.has(key)) {
      headed.add(key);
      if (!r.group.open) out.push({ heading: r.group, folded: shut });
    }
    if (r.lead) out.push({ ...r, folded: shut });
    else if (!r.nested) out.push(r);
    else if (!shut || r.w.active) out.push({ ...r, tree: "├─" });
  }
  // The last worktree shown closes its group.
  return out.map((r, i) => (r.tree && !out[i + 1]?.tree ? { ...r, tree: "└─" } : r));
}

// The owl's words and their tones, as Whiska's rows in the TUI's sidebar had
// them (lib/whiska/herdr_config.ex): the first that matches.
const TONES = [
  [(w) => w === "CI passed" || w === "ready" || w === "merged", "green"],
  [(w) => w.startsWith("merged ·"), "yellow"],
  [(w) => ["CI running", "auto-merge", "merging", "rebasing", "rebase after CI"].includes(w), "blue"],
  [(w) => w === "needs approval" || w === "needs rebase" || w.includes("open thread"), "yellow"],
  [(w) => ["CI failed", "CI stuck", "rebase refused", "conflict", "blocked", "closed"].includes(w), "red"],
  [(w) => w === "draft" || w === "unread", "dim"],
];
const tone = (word) => TONES.find(([match]) => match(word))?.[1] ?? null;
// The owl labels each round (`whiska.at`, ms): older than this, it has stopped.
export const STALE = 3 * 60 * 1000;

// The line under a worktree `space` whose terminal is a mouse's (labelled
// `whiska.branch`): the first line of its agent's last report (OSC 7501's
// `msg`), a question when it starts with ❓, then the owl's labels; null
// when there's nothing to show.
export function line(space, terminals, now) {
  // A remote space's id has its machine before it; that machine's labels don't.
  const id = space.machine ? space.id.slice(space.machine.length + 1) : space.id;
  const mouse = terminals.find((t) => t.labels?.["herdr.space"] === id && t.labels?.["whiska.branch"]);
  if (!mouse) return null;
  const msg = (mouse.report?.msg ?? "").split("\n")[0].trim();
  const labels = ["whiska.mr", "whiska.ci", "whiska.review"]
    .map((k) => mouse.labels[k])
    .filter(Boolean)
    .map((text) => ({ text, tone: tone(text) }));
  if (!msg && !labels.length) return null;
  return { msg, ask: msg.startsWith("❓"), labels, stale: now - Number(mouse.labels["whiska.at"] ?? now) > STALE };
}

// Whether a mouse's labels went stale in the `within` ms before `now`: a
// timer that looks that often redraws only then, as nothing live changes.
export function wentStale(terminals, now, within) {
  return terminals.some((t) => {
    const age = now - Number(t.labels?.["whiska.at"]) - STALE;
    return t.labels?.["whiska.branch"] && age > 0 && age <= within;
  });
}
