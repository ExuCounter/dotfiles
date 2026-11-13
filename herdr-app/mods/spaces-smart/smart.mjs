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
