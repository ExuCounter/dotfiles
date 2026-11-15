// Watches my open GitLab MRs. A new review thread, a failed pipeline or a conflict goes to
// the agent working that branch, or to a new space launched with the resolve prompt.
import { exec, run, spaces, agents, hc, notify } from "herdr";
import { gitlabRepository } from "./pr-status.js";

const POLL_MS = 120000;
const HOST = "gitlab.com";
const HOME = "/Users/volodymyrpotiichuk";
const PROMPT = `${HOME}/.config/herdr-app/mods/better-sidebar/git/mr-resolve.md`;
const PROJECTS = `${HOME}/Desktop/projects`;
const AGENT = ["claude", "--model", "opus", "--effort", "medium", "--permission-mode", "acceptEdits"];

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

export class MRWatcher {
  constructor() {
    try { this.seen = JSON.parse(localStorage.getItem("mr-watch.seen") ?? "{}"); } catch { this.seen = {}; }
  }

  start(cx) {
    this.poll(cx);
    cx.timer.every(POLL_MS, (cx) => this.poll(cx));
  }

  poll(cx) {
    if (this.busy) return;
    this.busy = true;
    cx.spawn(async () => {
      try {
        this.me ??= (await glab("user")).id;
        const mrs = await glab("merge_requests?scope=created_by_me&state=opened&per_page=50");
        const repos = await this.repos();
        for (const mr of mrs) {
          const repo = mr.references?.full?.split("!")[0];
          if (!repos[repo]) continue;
          try { await this.check(mr, repo, repos); } catch (error) { console.error(`mr-watch !${mr.iid}: ${error.message}`); }
        }
      } catch (error) {
        console.error(`mr-watch: ${error.message}`);
      } finally {
        try { localStorage.setItem("mr-watch.seen", JSON.stringify(this.seen)); } catch {}
        this.busy = false;
      }
    });
  }

  async check(mr, repo, repos) {
    const base = `projects/${encodeURIComponent(repo)}/merge_requests/${mr.iid}`;
    const [detail, discussions] = await Promise.all([
      glab(base),
      glab(`${base}/discussions?per_page=100`),
    ]);
    const events = [];
    for (const discussion of discussions) {
      const note = discussion.notes?.[0];
      if (!note?.resolvable || note.resolved || note.author?.id === this.me) continue;
      events.push({ key: `note:${discussion.id}`, text: `review thread ${discussion.id} by ${note.author?.username}` });
    }
    const pipeline = detail.head_pipeline;
    if (pipeline?.status === "failed")
      events.push({ key: `pipeline:${pipeline.id}`, text: `failed pipeline ${pipeline.web_url}` });
    if (detail.has_conflicts)
      events.push({ key: `conflict:${detail.sha}`, text: `conflict with ${detail.target_branch}` });

    const key = `${repo}!${mr.iid}`;
    const first = !this.seen[key];
    const seen = new Set(this.seen[key] ?? []);
    const fresh = events.filter((event) => !seen.has(event.key));
    this.seen[key] = events.map((event) => event.key);
    if (first || !fresh.length) return;
    await this.dispatch(mr, repos[repo], fresh);
  }

  async dispatch(mr, root, events) {
    const branch = mr.source_branch;
    const summary = `MR !${mr.iid} (${mr.web_url}) on ${branch}: ${events.map((event) => event.text).join("; ")}`;
    const space = spaces().find((s) => s.branch === branch);
    const agent = space && agents().find((a) => a.space === space.id && a.address);
    if (agent) {
      await hc(["send", agent.address, `MR watch: ${summary}. Read it with glab, fix what is this branch's to fix, commit, and say what you would push.`]);
      notify({ title: `MR !${mr.iid}: sent to ${branch}`, body: summary });
      return;
    }
    const folder = await this.worktree(root, branch);
    const template = await tool("cat", [PROMPT]);
    const task = template
      .replaceAll("{{mr_url}}", mr.web_url)
      .replaceAll("{{iid}}", String(mr.iid))
      .replaceAll("{{repo}}", mr.references?.full?.split("!")[0])
      .replaceAll("{{branch}}", branch)
      .replaceAll("{{target}}", mr.target_branch)
      .replaceAll("{{events}}", events.map((event) => `- ${event.text}`).join("\n"));
    await run("space.new", { name: branch, folder, argv: [...AGENT, "--name", branch], task });
    notify({ title: `MR !${mr.iid}: spawned ${branch}`, body: summary });
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
    const folder = `${root}/worktrees/${branch}`;
    await git(["fetch", "origin", branch]);
    const local = await exec("git", ["rev-parse", "--verify", "--quiet", `refs/heads/${branch}`], { cwd: root });
    await git(local.code === 0
      ? ["worktree", "add", folder, branch]
      : ["worktree", "add", "--track", "-b", branch, folder, `origin/${branch}`]);
    return folder;
  }
}
