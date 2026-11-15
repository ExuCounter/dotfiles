// Read-only PR discovery for each [machine, checkout]. This observer is separate
// from space rendering so frequent redraws never launch Git or GitHub commands.
import { exec } from "herdr";

export const PR_POLL_MS = 60000;
export const prPlaceKey = (machine, folder) => JSON.stringify([machine ?? null, folder]);
const PR_FIELDS =
  "id,number,title,url,state,isDraft,headRefName,headRepository,updatedAt,statusCheckRollup,reviewDecision,mergeStateStatus";

/** Terminal PR states win over draft/CI flags left over from when it was open. */
export function prAppearance(pr, colors) {
  if (pr.state === "MERGED") return { icon: "merged", color: colors.ansi5, label: "Merged" };
  if (pr.state === "CLOSED") return { icon: "closed", color: colors.ansi1, label: "Closed" };
  if (pr.isDraft) return { icon: "draft", color: colors.dim, label: "Draft" };
  const failed = (pr.statusCheckRollup ?? []).some((check) =>
    ["FAILURE", "ERROR", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE"].includes(
      String(check.conclusion || check.state || check.status).toUpperCase(),
    ),
  );
  const open = (color, label, ready = false) => ({ icon: "pull-request", color, label, ready });
  if (pr.mergeStateStatus === "DIRTY") return open(colors.ansi1, "Conflicts");
  if (failed) return open(colors.ansi1, "Checks failed");
  if (pr.reviewDecision === "CHANGES_REQUESTED") return open(colors.ansi3, "Changes requested");
  // CLEAN is GitHub's own "mergeable now": an empty decision means no review is required.
  if (pr.mergeStateStatus === "CLEAN" && (pr.reviewDecision === "APPROVED" || !pr.reviewDecision))
    return open(colors.ansi2, "Ready to merge", true);
  return open(colors.ansi2, "Open");
}

/** Only github.com remotes are supported. Never pass an arbitrary remote URL to gh. */
export function githubRepository(url) {
  return /^(?:https?:\/\/github\.com\/|git@github\.com:|ssh:\/\/git@github\.com\/)([\w.-]+\/[\w.-]+?)(?:\.git)?\/?$/.exec(
    url.trim(),
  )?.[1];
}

/** GitLab remotes as { host, repo }; github.com is left to githubRepository. */
export function gitlabRepository(url) {
  const m = /^(?:https?:\/\/|ssh:\/\/git@|git@)([\w.-]+)[:/]([\w.\/-]+?)(?:\.git)?\/?$/.exec(url.trim());
  if (!m || m[1] === "github.com" || !/gitlab/i.test(m[1])) return null;
  return { host: m[1], repo: m[2] };
}

function gitlabPr(mr, detail, repository) {
  const status = detail.detailed_merge_status;
  const pipeline = detail.head_pipeline?.status;
  return {
    id: `gitlab:${mr.id}`,
    number: mr.iid,
    title: mr.title,
    url: mr.web_url,
    state: { opened: "OPEN", merged: "MERGED", closed: "CLOSED" }[mr.state] ?? "OPEN",
    isDraft: !!mr.draft,
    updatedAt: mr.updated_at,
    statusCheckRollup: pipeline ? [{ status: pipeline === "failed" ? "FAILURE" : pipeline }] : [],
    mergeStateStatus: detail.has_conflicts || status === "conflict" ? "DIRTY" : status === "mergeable" ? "CLEAN" : "BLOCKED",
    reviewDecision: status === "not_approved" ? "REVIEW_REQUIRED" : null,
    repository,
  };
}

/**
 * One observer per sidebar. Git runs on the checkout's machine; gh runs locally,
 * using the person's existing authentication. No helper executable is required.
 * Maps include the machine in their keys so remote paths cannot collide.
 */
export class PRStatusObserver {
  constructor() {
    this.places = new Map(); // Current checkout snapshots, replaced on refresh.
    this.checked = new Map(); // Checkout key -> last attempt time and branch.
    this.entries = new Map(); // Checkout key -> last published PRs or error.
    this.cache = new Map(); // gh argument list -> short-lived response cache.
  }

  refresh(places, cx) {
    this.places = new Map(
      places
        .filter((place) => place.folder)
        .map((place) => [prPlaceKey(place.machine, place.folder), place]),
    );
    for (const key of this.entries.keys()) if (!this.places.has(key)) this.entries.delete(key);
    for (const key of this.checked.keys()) if (!this.places.has(key)) this.checked.delete(key);
    for (const [key, value] of this.cache)
      if (Date.now() - value.at >= PR_POLL_MS) this.cache.delete(key);
    if (this.busy) return;

    const due = [...this.places].filter(([key, place]) => {
      const last = this.checked.get(key);
      return !last || last.branch !== place.branch || Date.now() - last.at >= PR_POLL_MS;
    });
    // checkNew runs frequently. Do not spawn tasks or redraw on cache hits.
    if (!due.length) return;
    this.busy = true;
    cx.spawn(async (cx) => {
      try {
        for (const [key, place] of due) {
          if (!this.isCurrent(key, place)) continue;
          this.checked.set(key, { at: Date.now(), branch: place.branch });
          try {
            const prs = await this.lookup(place);
            if (this.isCurrent(key, place)) {
              this.entries.set(key, { prs, branch: place.branch, updated: Date.now() });
            }
          } catch (error) {
            if (this.isCurrent(key, place)) {
              const previous = this.entries.get(key);
              // Retain last-good status on a network error, but never carry a
              // previous branch's PR across a branch switch.
              this.entries.set(key, {
                prs: previous?.branch === place.branch ? previous.prs : [],
                branch: place.branch,
                error: error.message,
                updated: previous?.updated,
              });
            }
          }
          cx.notify();
        }
      } finally {
        this.busy = false;
      }
    });
  }

  // A lookup may finish after navigation or a branch switch. Publish only if
  // the caller's checkout snapshot still describes a tracked space.
  isCurrent(key, place) {
    return this.places.has(key) && this.places.get(key).branch === place.branch;
  }

  async lookup(place) {
    const git = (args) =>
      exec("git", ["--no-optional-locks", ...args], { cwd: place.folder, on: place.machine });
    const head = await git(["symbolic-ref", "--quiet", "--short", "HEAD"]);
    if (head.code !== 0) {
      if (head.code === 1 || /not a git repository/i.test(head.stderr ?? "")) return [];
      throw new Error("Cannot read checkout branch");
    }
    const branch = head.stdout.trim();
    // Explicit worktree bindings survive local branch renames and take
    // precedence over guessing a PR from matching head branch names.
    const association = await git(["config", "--get", `branch.${branch}.herdr-pr`]);
    if (association.code !== 0 && association.code !== 1)
      throw new Error("Cannot read PR association");
    const binding = /^([\w.-]+\/[\w.-]+)#([1-9][0-9]*)$/.exec(association.stdout?.trim() ?? "");
    if (binding) {
      const pr = await this.query("gh", [
        "pr",
        "view",
        binding[2],
        "--repo",
        binding[1],
        "--json",
        PR_FIELDS,
      ]);
      return [{ ...pr, repository: binding[1] }];
    }

    const remotes = await git(["remote"]);
    if (remotes.code !== 0) throw new Error("Cannot read Git remotes");
    const repositories = new Set();
    const gitlabs = new Map();
    for (const name of remotes.stdout.trim().split(/\r?\n/).filter(Boolean)) {
      const result = await git(["remote", "get-url", name]);
      if (result.code !== 0) throw new Error("Cannot read Git remote URL");
      const repository = githubRepository(result.stdout);
      if (repository) repositories.add(repository);
      const gitlab = gitlabRepository(result.stdout);
      if (gitlab) gitlabs.set(`${gitlab.host}/${gitlab.repo}`, gitlab);
    }

    const gitlabMatches = [];
    for (const { host, repo } of gitlabs.values()) {
      const base = `projects/${encodeURIComponent(repo)}/merge_requests`;
      const found = await this.query("glab", ["api", "--hostname", host,
        `${base}?source_branch=${encodeURIComponent(branch)}&state=all&order_by=updated_at&per_page=20`]);
      const mr = found.find((m) => m.state === "opened") ?? found[0];
      if (!mr) continue;
      const detail = await this.query("glab", ["api", "--hostname", host, `${base}/${mr.iid}`]);
      gitlabMatches.push(gitlabPr(mr, detail, repo));
    }
    if (gitlabMatches.length) return gitlabMatches;

    const candidates = [];
    const knownHeads = new Set([...repositories].map((repo) => repo.toLowerCase()));
    for (const repository of repositories) {
      const found = await this.query("gh", [
        "pr",
        "list",
        "--repo",
        repository,
        "--head",
        branch,
        "--state",
        "all",
        "--limit",
        "100",
        "--json",
        PR_FIELDS,
      ]);
      for (const pr of found) {
        // Branch names are not unique across forks. Only show PRs whose head
        // repository is one of this checkout's remotes, not somebody else's fork.
        if (
          pr.headRefName === branch &&
          knownHeads.has(pr.headRepository?.nameWithOwner?.toLowerCase())
        ) {
          candidates.push({ ...pr, repository });
        }
      }
    }
    const matches = [
      ...new Map(candidates.map((pr) => [pr.id ?? `${pr.repository}#${pr.number}`, pr])).values(),
    ].sort((a, b) => (b.updatedAt ?? "").localeCompare(a.updatedAt ?? ""));
    // A reused branch should show its current PR, not a historical merged one.
    const open = matches.filter((pr) => pr.state === "OPEN");
    return open.length ? open : matches.slice(0, 1);
  }

  async query(tool, args) {
    const key = JSON.stringify([tool, args]);
    const cached = this.cache.get(key);
    if (cached && Date.now() - cached.at < PR_POLL_MS) return cached.data;
    // Stamp when the call started, like the poll does, so the next poll never lands on this entry.
    const at = Date.now();
    let result;
    for (const bin of [tool, `/opt/homebrew/bin/${tool}`, `/usr/local/bin/${tool}`]) {
      try { result = await exec(bin, args); } catch { continue; }
      if (result.code !== 127) break;
    }
    if (!result || result.code !== 0)
      throw new Error((result?.stderr || `${tool} unavailable; check ${tool} auth login`).trim());
    const data = JSON.parse(result.stdout);
    this.cache.set(key, { at, data });
    return data;
  }
}
