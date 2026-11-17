import { exec } from "herdr";

// Shared helpers for Redline: git, the glab / gh CLIs and diff parsing.

// Reads that write nothing under .git, so a folder watch doesn't loop.
export const READ = ["--no-optional-locks", "-c", "core.fsmonitor=false", "-c", "diff.autoRefreshIndex=false"];

export const slug = (s) => s.replace(/[^A-Za-z0-9._-]+/g, "-").replace(/^-+|-+$/g, "");
export const msg = (e) => String(e?.message ?? e);

export async function git(cwd, args, on = null) {
  const r = await exec("git", args, { cwd, on });
  return { ok: r.code === 0, out: r.stdout.trim(), err: (r.stderr || r.stdout).trim() };
}

export async function gitOrThrow(cwd, args, on = null) {
  const r = await git(cwd, args, on);
  if (!r.ok) throw new Error(`git ${args[0]}: ${r.err}`);
  return r.out;
}

// git@host:owner/repo.git and https://host/owner/repo(.git) -> { host, repo }.
export function parseRemote(url) {
  const m = /^[\w.-]+@([^:/]+):(.+?)(?:\.git)?\/?$/.exec(url ?? "")
    ?? /^\w+:\/\/(?:[^@/]+@)?([^/:]+)(?::\d+)?\/(.+?)(?:\.git)?\/?$/.exec(url ?? "");
  return m ? { host: m[1], repo: m[2] } : null;
}

export const providerOf = (host) => (/(^|\.)github\.com$/.test(host) || /github/i.test(host) ? "github" : "gitlab");

// The repo around a folder: its main checkout, name, remote and default branch.
export async function repoAt(folder, on) {
  const top = await gitOrThrow(folder, ["rev-parse", "--show-toplevel"], on);
  const common = await gitOrThrow(top, ["rev-parse", "--path-format=absolute", "--git-common-dir"], on);
  const main = common.endsWith("/.git") ? common.slice(0, -5) : top;
  const url = (await git(top, ["remote", "get-url", "origin"], on)).out;
  const remote = parseRemote(url);
  let head = (await git(top, ["symbolic-ref", "--short", "refs/remotes/origin/HEAD"], on)).out;
  for (const name of ["main", "master", "develop", "trunk"]) {
    if (head) break;
    if ((await git(top, ["show-ref", "--verify", "--quiet", `refs/remotes/origin/${name}`], on)).ok) head = name;
  }
  return {
    top, main, on, name: main.split("/").pop(),
    host: remote?.host ?? null, repo: remote?.repo ?? null,
    provider: remote ? providerOf(remote.host) : null,
    defaultBranch: head.replace(/^origin\//, "") || "main",
  };
}

// Runs gh / glab, trying the usual install folders when PATH doesn't have them.
// Only a program that couldn't start (or a shell's 127) moves on to the next folder: one that
// ran and failed is the answer, so an API error is never hidden or a write sent twice.
export async function cli(name, args, opts = {}) {
  let last;
  for (const bin of [name, `/opt/homebrew/bin/${name}`, `/usr/local/bin/${name}`]) {
    let r;
    try { r = await exec(bin, args, opts); } catch (e) { last = e; continue; }
    if (r.code === 127) { last = new Error(`${name} not found`); continue; }
    if (r.code !== 0) throw new Error((r.stderr || r.stdout).trim() || `${name} exited ${r.code}`);
    return r.stdout;
  }
  throw new Error(`${name} isn't installed or can't start: ${msg(last)}`);
}

// Open merge/pull requests, newest activity first, in one shape for GitLab and GitHub.
export async function listRequests(repo) {
  const on = repo.on;
  if (repo.provider === "github") {
    const out = await cli("gh", ["pr", "list", "-R", `${repo.host}/${repo.repo}`, "--state", "open", "--limit", "50", "--json",
      "number,title,headRefName,baseRefName,author,isDraft,updatedAt,url,isCrossRepository"], { on });
    return JSON.parse(out).map((p) => ({
      number: p.number, title: p.title, branch: p.headRefName, target: p.baseRefName, author: p.author?.login ?? "",
      draft: p.isDraft, updated: Date.parse(p.updatedAt), url: p.url, fork: Boolean(p.isCrossRepository),
    }));
  }
  const path = `projects/${encodeURIComponent(repo.repo)}/merge_requests?state=opened&per_page=50&order_by=updated_at`;
  const out = await cli("glab", ["api", "--hostname", repo.host, path], { on });
  return JSON.parse(out).map((m) => ({
    number: m.iid, title: m.title, branch: m.source_branch, target: m.target_branch, author: m.author?.username ?? "",
    draft: Boolean(m.draft ?? m.work_in_progress), updated: Date.parse(m.updated_at), url: m.web_url,
    fork: m.source_project_id !== m.target_project_id,
  }));
}

// Local and origin branches, most recent commit first (for reviewing a branch with no request).
export async function listBranches(repo) {
  const r = await git(repo.main, ["for-each-ref", "--sort=-committerdate", "--count=60",
    "--format=%(refname:short)%09%(committerdate:unix)", "refs/heads", "refs/remotes/origin"], repo.on);
  const seen = new Set(), out = [];
  for (const line of r.out.split("\n").filter(Boolean)) {
    const [ref, at] = line.split("\t");
    const name = ref.replace(/^origin\//, "");
    if (name === "HEAD" || name === "origin" || seen.has(name)) continue;
    seen.add(name);
    out.push({ branch: name, updated: Number(at) * 1000 });
  }
  return out;
}

// git's error without the remote's banner noise ("remote:" lines, "=====" rules).
export function gitError(text) {
  const lines = (text ?? "").split("\n").map((l) => l.replace(/^remote:\s*/, "").trim())
    .filter((l) => l && !/^=+$/.test(l) && !/^Please make sure you have the correct access rights/.test(l) && l !== "and the repository exists.");
  return lines.join(" ").slice(0, 300);
}

// The checkout for a branch: an existing worktree that has it, else a new one under
// ~/.herdr/worktrees/<repo>/<branch> (where Herdr's worktree mod puts them, so the
// sidebar nests it under the repo). Forks are fetched from the request's head ref.
// A failed fetch never passes silently: with a local copy to fall back on it is returned in
// `warnings` (the review would show stale code); without one it is the error.
export async function checkout(repo, home, { branch, target, number, fork }) {
  const { main, on } = repo;
  const warnings = [];
  const t = await git(main, ["fetch", "--quiet", "origin", target], on);
  if (!t.ok) warnings.push(`Couldn't fetch ${target}: ${gitError(t.err)}`);
  let local = branch, start = `origin/${branch}`, upstream = { fetch: ["origin", branch], ref: start };
  if (fork) {
    const name = `${repo.provider === "github" ? "pr" : "mr"}-${number}`;
    local = `review/${name}`;
    const ref = repo.provider === "github" ? `pull/${number}/head` : `merge-requests/${number}/head`;
    // Into its own ref, not the branch: git won't fetch into a branch a worktree has out.
    start = `refs/review/${name}`;
    upstream = { fetch: ["origin", `+${ref}:${start}`], ref: start };
    const f = await git(main, ["fetch", "--quiet", ...upstream.fetch], on);
    if (!f.ok) throw new Error(`Couldn't fetch ${repo.provider === "github" ? "#" : "!"}${number}: ${gitError(f.err)}`);
  } else {
    const f = await git(main, ["fetch", "--quiet", "origin", branch], on);
    if (!f.ok) {
      start = null;
      if (/couldn't find remote ref/i.test(f.err)) upstream = null;
      // A branch origin doesn't have is a local-only branch; any other failure (auth, SSO,
      // network) means origin's copy is unknown.
      if (!/couldn't find remote ref/i.test(f.err)) {
        const hasLocal = (await git(main, ["show-ref", "--verify", "--quiet", `refs/heads/${branch}`], on)).ok;
        if (!hasLocal) throw new Error(`Couldn't fetch ${branch}: ${gitError(f.err)}`);
        warnings.push(`Couldn't fetch ${branch}, so this is your local copy and may be behind: ${gitError(f.err)}`);
      }
    }
  }
  const forward = async (path) => {
    if (!start || start === local) return;
    const m = await git(path, ["merge", "--ff-only", "--quiet", start], on);
    if (!m.ok) warnings.push(`Couldn't fast-forward ${local} to ${start}: ${gitError(m.err)}`);
  };

  // A review always gets its own Herdr worktree. An existing one under ~/.herdr/worktrees is
  // reused; a branch that's out somewhere else (your main checkout, say) can't be checked out
  // twice, so the review takes a branch of its own, review/<branch>, from the same commit.
  const root = `${home}/.herdr/worktrees/`;
  const trees = (await gitOrThrow(main, ["worktree", "list", "--porcelain"], on)).split(/\n\n+/).map((block) => ({
    path: /^worktree (.+)$/m.exec(block)?.[1], branch: /^branch refs\/heads\/(.+)$/m.exec(block)?.[1],
  })).filter((w) => w.path);
  const elsewhere = trees.find((w) => w.branch === local && !w.path.startsWith(root));
  if (elsewhere) {
    if (!start) start = local; // couldn't fetch: start from the local copy
    local = `review/${local}`;
  }
  const mine = trees.find((w) => w.branch === local && w.path.startsWith(root));
  if (mine) {
    await forward(mine.path);
    return { path: mine.path, branch: local, warnings, upstream };
  }

  const path = `${home}/.herdr/worktrees/${repo.name}/${slug(local)}`;
  const exists = (await git(main, ["show-ref", "--verify", "--quiet", `refs/heads/${local}`], on)).ok;
  if (exists) {
    await gitOrThrow(main, ["worktree", "add", path, local], on);
    await forward(path);
  } else if (start) {
    const track = !fork && start.startsWith("origin/") ? ["--track"] : [];
    await gitOrThrow(main, ["worktree", "add", ...track, "-b", local, path, start], on);
  } else throw new Error(`No branch named ${branch} here or on origin`);
  return { path, branch: local, warnings, upstream };
}

// Numbers each diff line once: old/new line numbers, kind (+ - space @).
// File headers (diff --git, index, ---/+++) only come before a file's first hunk; inside a
// hunk every line is content, so a removed "-- comment" (diff line "--- comment") or an
// added "++x" stays a row and the numbering after it stays right.
export function diffRows(text) {
  const rows = [];
  let old = 0, next = 0, inHunk = false;
  for (const line of text.split("\n")) {
    if (line.startsWith("diff --git ")) { inHunk = false; continue; }
    const m = /^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(line);
    if (m) { old = +m[1]; next = +m[2]; inHunk = true; rows.push({ kind: "@", text: line }); continue; }
    if (!inHunk) continue;
    const k = line[0];
    if (k === "-") rows.push({ kind: "-", old: old++, text: line.slice(1) });
    else if (k === "+") rows.push({ kind: "+", new: next++, text: line.slice(1) });
    else if (k === " ") rows.push({ kind: " ", old: old++, new: next++, text: line.slice(1) });
    // "\ No newline at end of file" and anything else: not a line of either file.
  }
  return rows;
}

// `git diff --numstat -z -M`: "add\tdel\tpath\0", or for a rename "add\tdel\t\0old\0new\0".
// -> [{ path, oldPath?, add, del, binary }]
export function numstat(out) {
  const parts = out.split("\0"), files = [];
  for (let i = 0; i < parts.length; i++) {
    if (!parts[i]) continue;
    const [a, d, ...rest] = parts[i].split("\t");
    let path = rest.join("\t"), oldPath = null;
    if (!path) { oldPath = parts[++i]; path = parts[++i]; }
    if (!path) continue;
    files.push({ path, ...(oldPath && oldPath !== path ? { oldPath } : {}), add: Number(a) || 0, del: Number(d) || 0, binary: a === "-" });
  }
  return files;
}
