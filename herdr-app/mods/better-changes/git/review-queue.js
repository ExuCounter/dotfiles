// What on a merge request still waits on someone: every open thread, and a person's comment
// I haven't answered. A bot's plain comment is a summary of its threads, never an item.
// No herdr imports, so node --test runs it. better-sidebar keeps an identical copy, since a mod
// can't import from outside its folder; the test fails when the two differ.

export const isBot = (author) => /_bot_|\bbot$/i.test(author?.username ?? "");

// GitLab masks the name of a group's bot to people outside the group.
export const displayName = (author) =>
  author?.name && !/^\*+$/.test(author.name) ? author.name : `@${author?.username ?? ""}`;

// A discussion with a note from a person, or null. CodeRabbit marks its notes, and its masked
// account would otherwise show as a long bot username. A thread on a line keeps the line it was
// written on, on the new side or, for a removed line, the old one.
export function toThread(discussion) {
  const notes = (discussion.notes ?? []).filter((note) => !note.system);
  const first = notes[0];
  if (!first) return null;
  const position = first.position;
  const onNew = position?.new_line != null;
  return {
    id: discussion.id,
    path: position ? (position.new_path ?? position.old_path) : null,
    line: (onNew ? position.new_line : position?.old_line) ?? null,
    side: onNew ? "new" : "old",
    resolvable: Boolean(first.resolvable),
    resolved: Boolean(first.resolved),
    notes: notes.map((note) => ({
      authorId: note.author?.id,
      author: note.author?.username ?? "",
      name: /coderabbit-ai-generated/.test(note.body ?? "") ? "CodeRabbit" : displayName(note.author),
      bot: isBot(note.author),
      body: note.body ?? "",
      at: Date.parse(note.created_at),
    })),
  };
}

const last = (notes) => notes[notes.length - 1];

const inQueue = (thread, me) => {
  if (thread.resolvable) return !thread.resolved;
  const first = thread.notes[0];
  return !first.bot && first.authorId !== me && last(thread.notes).authorId !== me;
};

// Waiting on me first, then the ones I answered last; each side oldest first. `dismissed` maps
// a thread to its last note's time when I dismissed it: it stays out until a newer note.
export function reviewQueue(threads, me, dismissed = {}) {
  return threads
    .filter((thread) => thread.notes.length && inQueue(thread, me))
    .filter((thread) => !(dismissed[thread.id] >= last(thread.notes).at))
    .map((thread) => ({ ...thread, waitingOn: last(thread.notes).authorId === me ? "them" : "me" }))
    .sort((a, b) => (a.waitingOn === b.waitingOn ? a.notes[0].at - b.notes[0].at : a.waitingOn === "me" ? -1 : 1));
}

// A note's first lines as the card shows them before "Show all"; a code block cut short is
// closed so the rest of the card still renders as prose.
export function excerpt(body, maxLines) {
  const lines = body.replace(/<!--[\s\S]*?-->/g, "").trim().split("\n");
  const kept = [];
  let filled = 0;
  for (const line of lines) {
    if (filled === maxLines) break;
    kept.push(line);
    if (line.trim()) filled++;
  }
  if (kept.length === lines.length) return { text: kept.join("\n"), clipped: false };
  const fences = kept.filter((line) => line.trimStart().startsWith("```")).length;
  return { text: [...kept, ...(fences % 2 ? ["```"] : [])].join("\n").trim(), clipped: true };
}

// What an agent reported on the threads it was sent, one JSON line per note from
// bin/thread-note; the newest note on a thread is its result.
export function threadResults(text) {
  const results = {};
  for (const line of text.split("\n")) {
    if (!line.trim()) continue;
    let note;
    try {
      note = JSON.parse(line);
    } catch {
      continue;
    }
    if (!note.thread || (results[note.thread]?.at ?? -1) > note.at) continue;
    results[note.thread] = { kind: note.kind, commit: note.commit, reason: note.reason, at: note.at };
  }
  return results;
}
