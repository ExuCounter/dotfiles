// The review inbox: what GitLab waits on me for, in shared("mr-inbox"). On my MRs (authored or
// assigned): review threads waiting on my answer, new comments, failed pipelines, conflicts. On
// MRs I review: a review not yet approved at the head commit, and answers in threads I'm in.
// Nothing goes to an agent until I hand an item over from the inbox.
import { exec, run, spaces, agents, hc, notify, shared, setShared, home } from "herdr";
import { gitlabRepository } from "./pr-status.js";
import { reviewQueue, toThread, isBot, displayName } from "./review-queue.js";

export const INBOX = "mr-inbox";
const POLL_MS = 120000;
// An MR untouched this long is left out.
const STALE_MS = 30 * 24 * 3600000;
const HOST = "gitlab.com";
const HOME = home();
const PROMPT = `${HOME}/.config/herdr-app/mods/better-sidebar/git/mr-resolve.md`;
const PROJECTS = `${HOME}/Desktop/projects`;
const AGENT = ["claude", "--model", "claude-opus-5-5", "--permission-mode", "acceptEdits"];

async function tool(bin, args, options = {}) {
  let result;
  for (const path of [bin, `/opt/homebrew/bin/${bin}`, `/usr/local/bin/${bin}`]) {
    try { result = await exec(path, args, options); } catch { continue; }
    if (result.code !== 127) break;
  }
  if (!result || result.code !== 0) throw new Error((result?.stderr || `${bin} failed`).trim());
  return result.stdout;
}

const glab = async (path) => JSON.parse(await tool("glab", ["api", "--hostname", HOST, path]));
// Every page, one item per line.
const glabAll = async (path) =>
  (await tool("glab", ["api", "--hostname", HOST, "--paginate", "--output", "ndjson", path]))
    .split("\n")
    .filter((line) => line.trim())
    .map((line) => JSON.parse(line));
const wait = (cx, ms) => new Promise((resolve) => cx.timer.after(ms, () => resolve()));

export const inbox = () => shared(INBOX) ?? { items: {}, mrs: {} };
export const inboxItems = () => Object.values(inbox().items ?? {});
export const pendingItems = () => inboxItems().filter((item) => item.status === "pending");

// An item handled from the inbox or the diff stays quiet until a newer note arrives.
export function settle(key, status) {
  const state = inbox();
  const item = state.items?.[key];
  if (!item) return;
  setShared(INBOX, { ...state, items: { ...state.items, [key]: { ...item, status, handledAt: Date.now() } } });
}

const visible = (body) => (body ?? "").replace(/<!--[\s\S]*?-->/g, "").trim();
const person = (note) => ({ author: note.author?.username ?? "", name: displayName(note.author) });

// The newest copy polls: a reload stops the old build's timers, and globalThis outlives them.
export class MRInbox {
  start(cx) {
    this.poll(cx);
    cx.timer.every(POLL_MS, (cx) => this.poll(cx));
  }

  poll(cx) {
    if (this.busy || globalThis.mrInbox !== this) return;
    this.busy = true;
    cx.spawn(async (cx) => {
      try {
        this.user ??= await glab("user");
        this.me = this.user.id;
        const list = (filter) => glab(`merge_requests?${filter}&state=opened&scope=all&per_page=100`);
        const [authored, assigned, reviewing] = await Promise.all([
          list(`author_id=${this.me}`),
          list(`assignee_id=${this.me}`),
          list(`reviewer_id=${this.me}`),
        ]);
        const roles = new Map();
        for (const mr of [...authored, ...assigned]) roles.set(mr.id, { mr, role: "mine" });
        for (const mr of reviewing) if (!roles.has(mr.id)) roles.set(mr.id, { mr, role: "review" });
        const repos = await this.repos();
        const found = {};
        const watched = {};
        for (const { mr, role } of roles.values()) {
          const repo = mr.references?.full?.split("!")[0];
          if (!repos[repo] || Date.now() - Date.parse(mr.updated_at) > STALE_MS) continue;
          const key = `${repo}!${mr.iid}`;
          watched[key] = { role, since: inbox().mrs?.[key]?.since ?? Date.now() };
          try {
            const collect = role === "mine" ? this.collect : this.collectReview;
            const { items, status } = await collect.call(this, mr, repo, repos[repo], watched[key].since);
            for (const item of items) found[item.key] = item;
            watched[key] = { ...watched[key], ...status };
          } catch (error) {
            console.error(`mr-inbox !${mr.iid}: ${error.message}`);
          }
        }
        this.merge(found, watched);
      } catch (error) {
        setShared(INBOX, { ...inbox(), error: error.message, at: Date.now() });
      } finally {
        this.busy = false;
        cx.notify();
      }
    });
  }

  // Keeps what was decided about an item; a note newer than that decision makes it pending again.
  merge(found, watched) {
    const before = inbox().items ?? {};
    const items = {};
    const fresh = [];
    for (const [key, item] of Object.entries(found)) {
      const old = before[key];
      const quiet = old && old.status !== "pending" && (old.handledAt ?? 0) >= item.at;
      items[key] = quiet ? { ...item, status: old.status, handledAt: old.handledAt } : { ...item, status: "pending" };
      if (!quiet && old?.status !== "pending" && this.polled) fresh.push(item);
    }
    setShared(INBOX, { items, mrs: watched, at: Date.now(), error: null });
    this.polled = true;
    for (const item of fresh)
      notify({
        title: `!${item.iid} · ${item.title}`,
        body: item.summary,
        level: item.kind === "pipeline" || item.kind === "conflict" ? "warning" : "info",
      });
  }

  // What an MR I review waits on me for: my review of its head commit, answers to me.
  async collectReview(mr, repo, root) {
    const base = `projects/${encodeURIComponent(repo)}/merge_requests/${mr.iid}`;
    const [detail, discussions, approvals] = await Promise.all([
      glab(base),
      glabAll(`${base}/discussions?per_page=100`),
      glab(`${base}/approvals`),
    ]);
    const about = this.about(mr, repo, root, "review");
    const items = [];
    const approved = (approvals.approved_by ?? []).some((entry) => entry.user?.id === this.me);
    if (!approved && !mr.draft)
      items.push({
        ...about,
        key: `${repo}!${mr.iid}:review:${detail.sha}`,
        kind: "review",
        // Quiet once dismissed, until a push makes it a new commit to review.
        at: 0,
        updated: Date.parse(detail.updated_at),
        author: mr.author?.name || mr.author?.username || "",
        summary: `${mr.author?.name ?? "Someone"} wants your review`,
      });
    for (const discussion of discussions) {
      const notes = (discussion.notes ?? []).filter((note) => !note.system);
      const first = notes[0];
      const last = notes[notes.length - 1];
      if (!first?.resolvable || first.resolved || last.author?.id === this.me) continue;
      if (!notes.some((note) => note.author?.id === this.me)) continue;
      items.push(this.threadItem(about, discussion, notes, "reply"));
    }
    return { items, status: this.status(about, detail, discussions, approvals) };
  }

  // Where the MR stands, waiting on me or not: shown under the inbox's items.
  status(about, detail, discussions, approvals) {
    const queue = reviewQueue(discussions.map(toThread).filter(Boolean), this.me, shared("review-queue.dismissed") ?? {});
    return {
      ...about,
      draft: Boolean(detail.draft),
      pipeline: detail.head_pipeline?.status ?? null,
      pipelineUrl: detail.head_pipeline?.web_url ?? null,
      conflicts: Boolean(detail.has_conflicts),
      approved: (approvals.approved_by ?? []).length,
      required: approvals.approvals_required ?? 0,
      open: queue.filter((item) => item.waitingOn === "me").length,
      waiting: queue.filter((item) => item.waitingOn === "them").length,
      queue: queue.map((item) => ({
        id: item.id,
        path: item.path,
        line: item.line,
        waitingOn: item.waitingOn,
        author: item.notes[item.notes.length - 1].name,
        at: item.notes[item.notes.length - 1].at,
      })),
      updated: Date.parse(detail.updated_at),
    };
  }

  about(mr, repo, root, role) {
    return {
      role,
      repo,
      root,
      host: HOST,
      iid: mr.iid,
      url: mr.web_url,
      title: mr.title,
      branch: mr.source_branch,
      target: mr.target_branch,
    };
  }

  threadItem(about, discussion, notes, kind) {
    const first = notes[0];
    const last = notes[notes.length - 1];
    const position = first.position;
    const onNew = position?.new_line != null;
    return {
      ...about,
      key: `${about.repo}!${about.iid}#${discussion.id}`,
      kind,
      thread: discussion.id,
      path: position ? (position.new_path ?? position.old_path) : null,
      line: position ? (onNew ? position.new_line : position.old_line) : null,
      notes: notes.map((note) => ({ ...person(note), body: visible(note.body), at: Date.parse(note.created_at) })),
      at: Date.parse(last.created_at),
      summary: `${person(last).name}: ${visible(last.body).split("\n")[0].slice(0, 140)}`,
    };
  }

  async collect(mr, repo, root, since) {
    const base = `projects/${encodeURIComponent(repo)}/merge_requests/${mr.iid}`;
    const [detail, discussions, approvals] = await Promise.all([
      glab(base),
      glabAll(`${base}/discussions?per_page=100`),
      glab(`${base}/approvals`),
    ]);
    const about = this.about(mr, repo, root, "mine");
    const items = [];
    for (const discussion of discussions) {
      const notes = (discussion.notes ?? []).filter((note) => !note.system);
      const first = notes[0];
      const last = notes[notes.length - 1];
      if (!first || last.author?.id === this.me) continue;
      // A comment that can't be resolved has no end of its own: only ones after the MR was first seen count.
      if (first.resolvable ? first.resolved : Date.parse(first.created_at) < since || isBot(first.author)) continue;
      items.push(this.threadItem(about, discussion, notes, first.resolvable ? "thread" : "comment"));
    }
    const pipeline = detail.head_pipeline;
    if (pipeline?.status === "failed")
      items.push({
        ...about,
        key: `${repo}!${mr.iid}:pipeline:${pipeline.id}`,
        kind: "pipeline",
        pipeline: pipeline.web_url,
        at: Date.parse(pipeline.updated_at ?? pipeline.created_at) || Date.now(),
        summary: "Pipeline failed",
      });
    if (detail.has_conflicts)
      items.push({
        ...about,
        key: `${repo}!${mr.iid}:conflict:${detail.sha}`,
        kind: "conflict",
        at: Date.parse(detail.updated_at) || Date.now(),
        summary: `Conflicts with ${detail.target_branch}`,
      });
    return { items, status: this.status(about, detail, discussions, approvals) };
  }

  // ── Handing an item over ──────────────────────────────────────────────────

  // The space on the branch's worktree, made when there's none. Spaces know their folder, not
  // their branch, so the worktree is found first.
  async space(item, cx) {
    const folder = await this.worktree(item.root, item.branch);
    const onFolder = () => spaces().find((s) => s.folder === folder);
    if (onFolder()) return onFolder();
    run("space.new", { name: item.branch, folder });
    for (let i = 0; i < 40; i++) {
      if (onFolder()) return onFolder();
      await wait(cx, 250);
    }
    throw new Error(`No space came up for ${item.branch}`);
  }

  // To the agent on the item's branch, or a new one in its space.
  async toAgent(item, cx) {
    const template = await tool("cat", [PROMPT]);
    const task = template
      .replaceAll("{{mr_url}}", item.url)
      .replaceAll("{{iid}}", String(item.iid))
      .replaceAll("{{repo}}", item.repo)
      .replaceAll("{{branch}}", item.branch)
      .replaceAll("{{target}}", item.target)
      .replaceAll("{{events}}", describe(item));
    const space = await this.space(item, cx);
    const agent = agents().find((a) => a.space === space.id && a.address);
    if (agent) await hc(["send", agent.address, task]);
    else run("tab.new", { space: space.id, name: "Review", folder: space.folder, argv: AGENT, task });
    settle(item.key, "sent");
  }

  // GitLab project -> main checkout, found from open spaces and clones under PROJECTS.
  async repos() {
    if (this.known && Date.now() - this.known.at < 30 * 60000) return this.known.map;
    const folders = new Set(spaces().map((s) => s.folder).filter(Boolean));
    try {
      const found = await tool("find", [PROJECTS, "-maxdepth", "4", "-name", ".git", "-type", "d", "-prune"]);
      for (const line of found.split("\n")) if (line) folders.add(line.slice(0, -5));
    } catch {}
    const map = {};
    for (const folder of folders) {
      try {
        const remote = gitlabRepository(await tool("git", ["remote", "get-url", "origin"], { cwd: folder }));
        if (!remote || remote.host !== HOST || map[remote.repo]) continue;
        const common = (await tool("git", ["rev-parse", "--path-format=absolute", "--git-common-dir"], { cwd: folder })).trim();
        map[remote.repo] = common.replace(/\/\.git$/, "");
      } catch {}
    }
    this.known = { at: Date.now(), map };
    return map;
  }

  async worktree(root, branch) {
    const git = (args) => tool("git", args, { cwd: root });
    const list = await git(["worktree", "list", "--porcelain"]);
    const existing = list.split("\n\n").find((entry) => entry.includes(`branch refs/heads/${branch}\n`) || entry.endsWith(`branch refs/heads/${branch}`));
    if (existing) return existing.split("\n")[0].replace("worktree ", "");
    const folder = `${home()}/.herdr/worktrees/${root.split("/").pop()}/${branch.replace(/[^\p{L}\p{M}\p{N}._-]+/gu, "-")}`;
    await git(["fetch", "origin", branch]);
    const local = await exec("git", ["rev-parse", "--verify", "--quiet", `refs/heads/${branch}`], { cwd: root });
    await git(local.code === 0
      ? ["worktree", "add", folder, branch]
      : ["worktree", "add", "--track", "-b", branch, folder, `origin/${branch}`]);
    return folder;
  }
}

// The item as the agent reads it: the whole thread, quoted, where it is.
export function describe(item) {
  if (item.kind === "pipeline") return `- Failed pipeline: ${item.pipeline}`;
  if (item.kind === "conflict") return `- Conflicts with \`${item.target}\``;
  const where = item.path ? `\`${item.path}${item.line ? `:${item.line}` : ""}\`` : "the merge request";
  const quote = (text) => text.split("\n").map((line) => `> ${line}`).join("\n");
  return [
    `- ${item.kind === "thread" ? "Review thread" : "Comment"} on ${where}:`,
    ...item.notes.map((note) => `\n**${note.name || note.author}:**\n${quote(note.body || " ")}`),
  ].join("\n");
}
