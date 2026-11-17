import { cli, msg } from "./lib.js";

// GitLab and GitHub through glab / gh, in one shape for both:
//   detail(repo, n) -> { description, approvedBy[], approvedByMe, canApprove, commits[], threads[] }
//   thread: { id, path, line, resolved, inline, notes: [{ author, body, at }] }
//   approve / unapprove(repo, n), reply(repo, n, thread, body), comment(repo, n, body)

const gl = (repo, path, args = []) => cli("glab", ["api", "--hostname", repo.host, ...args, path], { on: repo.on });
const glp = (repo, n) => `projects/${encodeURIComponent(repo.repo)}/merge_requests/${n}`;
const gh = (repo, args) => cli("gh", args, { on: repo.on });
const ghApi = (repo, path, args = []) => gh(repo, ["api", "--hostname", repo.host, ...args, path]);
const ghR = (repo) => ["-R", `${repo.host}/${repo.repo}`];

// Every page of a list. glab 1.127 prints one JSON array per page back to back even in its
// default json output, so ask for one item per line; gh's --slurp wraps the pages in an array.
async function glList(repo, path) {
  const out = await gl(repo, path, ["--paginate", "--output", "ndjson"]);
  return out.split("\n").filter((l) => l.trim()).map((l) => JSON.parse(l));
}
async function ghList(repo, path) {
  return JSON.parse(await ghApi(repo, path, ["--paginate", "--slurp"])).flat();
}

async function gitlabDetail(repo, n) {
  const [mr, approvals, commits, discussions] = await Promise.all([
    gl(repo, glp(repo, n)).then(JSON.parse),
    gl(repo, `${glp(repo, n)}/approvals`).then(JSON.parse).catch(() => ({})),
    glList(repo, `${glp(repo, n)}/commits?per_page=100`),
    glList(repo, `${glp(repo, n)}/discussions?per_page=100`),
  ]);
  const threads = discussions
    .map((d) => {
      const notes = d.notes.filter((x) => !x.system);
      const first = notes[0], pos = first?.position;
      return first && {
        id: d.id, inline: Boolean(pos), path: pos?.new_path ?? pos?.old_path ?? null, line: pos?.new_line ?? pos?.old_line ?? null,
        side: pos?.new_line != null ? "new" : "old",
        resolvable: Boolean(first.resolvable), resolved: Boolean(first.resolved),
        notes: notes.map((x) => ({ author: x.author?.username ?? "", body: x.body ?? "", at: Date.parse(x.created_at) })),
      };
    })
    .filter(Boolean);
  return {
    description: mr.description ?? "",
    state: mr.state, draft: Boolean(mr.draft), author: mr.author?.username ?? "",
    approvedBy: (approvals.approved_by ?? []).map((a) => a.user?.username).filter(Boolean),
    approvedByMe: Boolean(approvals.user_has_approved),
    canApprove: approvals.user_can_approve !== false,
    commits: commits.map((c) => ({ sha: c.short_id, title: c.title, author: c.author_name, at: Date.parse(c.created_at) })),
    threads,
  };
}

async function githubDetail(repo, n) {
  const [pr, me, inline] = await Promise.all([
    gh(repo, ["pr", "view", String(n), ...ghR(repo), "--json", "body,author,state,isDraft,latestReviews,comments,commits,reviews"]).then(JSON.parse),
    ghApi(repo, "user", ["--jq", ".login"]).then((s) => s.trim()).catch(() => ""),
    ghList(repo, `repos/${repo.repo}/pulls/${n}/comments?per_page=100`),
  ]);
  const approvedBy = (pr.latestReviews ?? []).filter((r) => r.state === "APPROVED").map((r) => r.author?.login).filter(Boolean);
  // Inline comments thread through in_reply_to_id; the thread's id is its first comment's.
  const byId = new Map();
  for (const c of inline) {
    const root = c.in_reply_to_id ?? c.id;
    if (!byId.has(root)) byId.set(root, { id: String(root), inline: true, path: c.path, line: c.line ?? c.original_line ?? null, side: c.side === "LEFT" ? "old" : "new", resolvable: false, resolved: false, notes: [] });
    byId.get(root).notes.push({ author: c.user?.login ?? "", body: c.body ?? "", at: Date.parse(c.created_at) });
  }
  const general = [
    ...(pr.comments ?? []).map((c) => ({ author: c.author?.login ?? "", body: c.body ?? "", at: Date.parse(c.createdAt) })),
    ...(pr.reviews ?? []).filter((r) => r.body).map((r) => ({ author: r.author?.login ?? "", body: `**${r.state.toLowerCase().replace("_", " ")}**\n\n${r.body}`, at: Date.parse(r.submittedAt) })),
  ].map((x, i) => ({ id: `c${i}`, inline: false, path: null, line: null, resolvable: false, resolved: false, notes: [x], general: true }));
  return {
    description: pr.body ?? "", state: pr.state?.toLowerCase(), draft: Boolean(pr.isDraft), author: pr.author?.login ?? "",
    approvedBy, approvedByMe: Boolean(me) && approvedBy.includes(me), canApprove: Boolean(me) && pr.author?.login !== me,
    commits: (pr.commits ?? []).map((c) => ({
      sha: c.oid.slice(0, 8), title: c.messageHeadline, author: c.authors?.[0]?.login || c.authors?.[0]?.name || "", at: Date.parse(c.committedDate),
    })),
    threads: [...general, ...byId.values()].sort((a, b) => a.notes[0].at - b.notes[0].at),
  };
}

export const detail = (repo, n) => (repo.provider === "github" ? githubDetail(repo, n) : gitlabDetail(repo, n));

export async function approve(repo, n, on = true) {
  if (repo.provider === "github") {
    if (!on) throw new Error("GitHub can't withdraw an approval; dismiss it on the website.");
    return gh(repo, ["pr", "review", String(n), ...ghR(repo), "--approve"]);
  }
  return gl(repo, `${glp(repo, n)}/${on ? "approve" : "unapprove"}`, ["-X", "POST"]);
}

// A reply in a thread; GitHub's general comments have no threads, so they get a new comment.
export async function reply(repo, n, thread, body) {
  if (repo.provider === "github") {
    if (thread.general) return comment(repo, n, body);
    return ghApi(repo, `repos/${repo.repo}/pulls/${n}/comments/${thread.id}/replies`, ["-X", "POST", "-f", `body=${body}`]);
  }
  return gl(repo, `${glp(repo, n)}/discussions/${thread.id}/notes`, ["-X", "POST", "-f", `body=${body}`]);
}

export async function comment(repo, n, body) {
  if (repo.provider === "github") return gh(repo, ["pr", "comment", String(n), ...ghR(repo), "--body", body]);
  return gl(repo, `${glp(repo, n)}/notes`, ["-X", "POST", "-f", `body=${body}`]);
}

export async function resolve(repo, n, thread, resolved) {
  if (repo.provider !== "gitlab") throw new Error("Resolving threads is GitLab only here.");
  return gl(repo, `${glp(repo, n)}/discussions/${thread.id}?resolved=${resolved}`, ["-X", "PUT"]);
}

// Commits of a branch with no request: what it has that its target doesn't.
export async function branchCommits(git, target, branch) {
  const ref = (await git(["rev-parse", "--verify", "--quiet", branch])).ok ? branch : `origin/${branch}`;
  const r = await git(["log", "--max-count=100", "--format=%h%x09%s%x09%an%x09%ct", `origin/${target}..${ref}`]);
  return r.out.split("\n").filter(Boolean).map((l) => {
    const [sha, title, author, at] = l.split("\t");
    return { sha, title, author, at: Number(at) * 1000 };
  });
}

// ---- line comments and reviews ----
//
// An anchor is a diff line as the review pane numbers it:
//   { path, oldPath?, kind: "+" | "-" | " ", old, new, start?: { kind, old, new } }
//   (oldPath: a renamed file's old name; start: a range's first line, GitHub only)

// Sends a JSON body through the CLI on stdin (works on another machine too: no temp file).
async function send(repo, method, path, payload) {
  const tool = repo.provider === "github" ? "gh" : "glab";
  const script = 'export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"; printf "%s" "$1" | "$0" api --hostname "$2" -X "$3" -H "Content-Type: application/json" --input - "$4"';
  return cli("sh", ["-c", script, tool, JSON.stringify(payload), repo.host, method, path], { on: repo.on });
}

const ghSide = (kind) => (kind === "-" ? "LEFT" : "RIGHT");
const ghLine = (a) => (a.kind === "-" ? a.old : a.new);

function gitlabPosition(refs, a) {
  return {
    position_type: "text", base_sha: refs.base, start_sha: refs.start, head_sha: refs.head,
    old_path: a.oldPath ?? a.path, new_path: a.path,
    ...(a.kind !== "+" ? { old_line: a.old } : {}), ...(a.kind !== "-" ? { new_line: a.new } : {}),
  };
}

function githubComment(a, body) {
  const c = { path: a.path, body, line: ghLine(a), side: ghSide(a.kind) };
  if (a.start && (a.start.new ?? a.start.old) !== (a.new ?? a.old)) {
    c.start_line = ghLine(a.start); c.start_side = ghSide(a.start.kind);
  }
  return c;
}

// The commits a position is relative to: { base, start, head }.
export async function refs(repo, n) {
  if (repo.provider === "github") {
    const pr = JSON.parse(await ghApi(repo, `repos/${repo.repo}/pulls/${n}`));
    return { base: pr.base.sha, start: pr.base.sha, head: pr.head.sha };
  }
  const mr = JSON.parse(await gl(repo, glp(repo, n)));
  const d = mr.diff_refs ?? {};
  return { base: d.base_sha, start: d.start_sha, head: d.head_sha ?? mr.sha };
}

// Posts one comment on a line now.
export function lineComment(repo, n, r, a, body) {
  if (repo.provider === "github") {
    return send(repo, "POST", `repos/${repo.repo}/pulls/${n}/comments`, { ...githubComment(a, body), commit_id: r.head });
  }
  return send(repo, "POST", `${glp(repo, n)}/discussions`, { body, position: gitlabPosition(r, a) });
}

// Pending review comments. GitLab keeps them as draft notes on the server (they show as
// pending on the website too); GitHub's are kept by the pane until the review is submitted.
export async function addDraft(repo, n, r, a, body) {
  if (repo.provider === "github") return { id: `local-${Date.now()}`, local: true };
  const d = JSON.parse(await send(repo, "POST", `${glp(repo, n)}/draft_notes`, { note: body, position: gitlabPosition(r, a) }));
  return { id: d.id };
}

export async function listDrafts(repo, n) {
  if (repo.provider === "github") return null;
  const list = await glList(repo, `${glp(repo, n)}/draft_notes?per_page=100`);
  return list.map((d) => ({
    id: d.id, body: d.note, path: d.position?.new_path ?? d.position?.old_path ?? null,
    old: d.position?.old_line ?? null, new: d.position?.new_line ?? null,
    kind: d.position?.new_line == null ? "-" : d.position?.old_line == null ? "+" : " ",
  }));
}

export function deleteDraft(repo, n, draft) {
  if (repo.provider === "github" || draft.local) return Promise.resolve();
  return gl(repo, `${glp(repo, n)}/draft_notes/${draft.id}`, ["-X", "DELETE"]);
}

// Submits the review: event is "COMMENT", "APPROVE" or (GitHub) "REQUEST_CHANGES".
export async function submitReview(repo, n, r, drafts, body, event) {
  if (repo.provider === "github") {
    const payload = { commit_id: r.head, event, comments: drafts.map((d) => githubComment(d.anchor, d.body)) };
    if (body) payload.body = body;
    return send(repo, "POST", `repos/${repo.repo}/pulls/${n}/reviews`, payload);
  }
  if (body) await send(repo, "POST", `${glp(repo, n)}/draft_notes`, { note: body });
  if (drafts.length || body) await gl(repo, `${glp(repo, n)}/draft_notes/bulk_publish`, ["-X", "POST"]);
  if (event === "APPROVE") await approve(repo, n, true);
}

// Closes the request without merging.
export function closeRequest(repo, n) {
  if (repo.provider === "github") return gh(repo, ["pr", "close", String(n), ...ghR(repo)]);
  return send(repo, "PUT", glp(repo, n), { state_event: "close" });
}

// ---- the request list's extras: pipeline, unresolved threads, who's asked to review ----
//
// listStatus(repo) -> { me, byNumber: { [n]: { ci, unresolved, reviewers[], approvedBy[] } } }
// ci: "success" | "failed" | "running" | "pending" | "canceled" | null. One GraphQL query each.
const CI = {
  SUCCESS: "success", FAILED: "failed", FAILURE: "failed", ERROR: "failed", CANCELED: "canceled", CANCELLED: "canceled",
  RUNNING: "running", PENDING: "pending", EXPECTED: "pending", CREATED: "pending", PREPARING: "pending",
  WAITING_FOR_RESOURCE: "pending", SCHEDULED: "pending", MANUAL: "pending", SKIPPED: null,
};

export async function listStatus(repo) {
  if (repo.provider === "github") {
    const [owner, name] = repo.repo.split("/");
    const query = `query($owner: String!, $name: String!) { viewer { login } repository(owner: $owner, name: $name) {
      pullRequests(states: OPEN, first: 50, orderBy: {field: UPDATED_AT, direction: DESC}) { nodes { number title isDraft
        mergeStateStatus reviewDecision author { login }
        reviewRequests(first: 20) { nodes { requestedReviewer { ... on User { login } } } }
        latestReviews(first: 20) { nodes { state author { login } } }
        reviewThreads(first: 100) { nodes { isResolved } }
        commits(last: 1) { nodes { commit { statusCheckRollup { state } } } } } } } }`;
    const d = JSON.parse(await ghApi(repo, "graphql", ["-f", `query=${query}`, "-f", `owner=${owner}`, "-f", `name=${name}`])).data;
    const byNumber = {};
    for (const p of d.repository.pullRequests.nodes) {
      byNumber[p.number] = {
        title: p.title, author: p.author?.login ?? "", draft: p.isDraft,
        blockers: [blockerText("github", p.mergeStateStatus), p.reviewDecision === "CHANGES_REQUESTED" && "Changes were requested",
          p.reviewDecision === "REVIEW_REQUIRED" && "Needs an approving review"].filter(Boolean),
        ci: CI[p.commits.nodes[0]?.commit?.statusCheckRollup?.state] ?? null,
        unresolved: p.reviewThreads.nodes.filter((t) => !t.isResolved).length,
        reviewers: p.reviewRequests.nodes.map((r) => r.requestedReviewer?.login).filter(Boolean),
        approvedBy: p.latestReviews.nodes.filter((r) => r.state === "APPROVED").map((r) => r.author?.login).filter(Boolean),
      };
    }
    return { me: d.viewer.login, byNumber };
  }
  const query = `query($path: ID!) { currentUser { username } project(fullPath: $path) {
    mergeRequests(state: opened, first: 50, sort: UPDATED_DESC) { nodes { iid title draft detailedMergeStatus author { username } headPipeline { status }
      reviewers { nodes { username } } approvedBy { nodes { username } }
      resolvableDiscussionsCount resolvedDiscussionsCount } } } }`;
  const d = JSON.parse(await gl(repo, "graphql", ["-f", `query=${query}`, "-f", `path=${repo.repo}`])).data;
  const byNumber = {};
  for (const m of d.project.mergeRequests.nodes) {
    const block = blockerText("gitlab", m.detailedMergeStatus);
    byNumber[m.iid] = {
      title: m.title, author: m.author?.username ?? "", draft: m.draft, blockers: block ? [block] : [],
      ci: CI[m.headPipeline?.status] ?? null,
      unresolved: Math.max(0, (m.resolvableDiscussionsCount ?? 0) - (m.resolvedDiscussionsCount ?? 0)),
      reviewers: m.reviewers.nodes.map((r) => r.username),
      approvedBy: m.approvedBy.nodes.map((r) => r.username),
    };
  }
  return { me: d.currentUser?.username ?? "", byNumber };
}

// Edits a pending comment's text (GitLab's live on the server; GitHub's are the pane's own).
export function updateDraft(repo, n, draft, body) {
  if (repo.provider === "github" || draft.local) return Promise.resolve();
  return send(repo, "PUT", `${glp(repo, n)}/draft_notes/${draft.id}`, { note: body });
}

// ---- pipeline ----
//
// pipeline(repo, n) -> null | { id, status, url, groups: [{ name, jobs: [job] }] }
// job: { id, name, status, duration, url, allowFailure, run? (GitHub run id), manual? }
// status: "success" | "failed" | "running" | "pending" | "canceled" | "skipped" | "manual"
const JOB = {
  success: "success", failed: "failed", running: "running", pending: "pending", created: "pending", preparing: "pending",
  waiting_for_resource: "pending", scheduled: "pending", canceled: "canceled", skipped: "skipped", manual: "manual",
  pass: "success", fail: "failed", skipping: "skipped", cancel: "canceled",
};

async function gitlabJobs(repo, project, pid) {
  const base = `projects/${project}/pipelines/${pid}`;
  const [jobs, bridges] = await Promise.all([glList(repo, `${base}/jobs?per_page=100`), glList(repo, `${base}/bridges?per_page=100`)]);
  const job = (j) => ({ id: j.id, name: j.name, stage: j.stage, status: JOB[j.status] ?? j.status, duration: j.duration ?? null,
    url: j.web_url, allowFailure: Boolean(j.allow_failure), manual: j.status === "manual", project });
  const groups = [];
  const stageOf = (name) => { let g = groups.find((x) => x.name === name); if (!g) groups.push(g = { name, jobs: [] }); return g; };
  for (const j of [...jobs].reverse()) stageOf(j.stage).jobs.push(job(j));
  for (const b of bridges) {
    stageOf(b.stage).jobs.push({ ...job(b), bridge: true });
    const down = b.downstream_pipeline;
    if (down?.id) {
      const child = await gitlabJobs(repo, down.project_id ?? project, down.id);
      for (const g of child) groups.push({ name: `${b.name} › ${g.name}`, jobs: g.jobs });
    }
  }
  return groups;
}

export async function pipeline(repo, n) {
  if (repo.provider === "github") {
    const checks = JSON.parse(await gh(repo, ["pr", "checks", String(n), ...ghR(repo), "--json", "name,state,bucket,link,startedAt,completedAt,workflow"])
      .catch((e) => (/no checks/i.test(msg(e)) ? "[]" : Promise.reject(e))));
    if (!checks.length) return null;
    const groups = [];
    for (const c of checks) {
      const name = c.workflow || "Checks";
      let g = groups.find((x) => x.name === name);
      if (!g) groups.push(g = { name, jobs: [] });
      const m = /\/actions\/runs\/(\d+)\/job\/(\d+)/.exec(c.link ?? "");
      const secs = c.startedAt && c.completedAt ? (Date.parse(c.completedAt) - Date.parse(c.startedAt)) / 1000 : null;
      g.jobs.push({ id: m?.[2] ?? null, run: m?.[1] ?? null, name: c.name, status: JOB[c.bucket] ?? "pending", duration: secs && secs > 0 ? secs : null, url: c.link });
    }
    const all = groups.flatMap((g) => g.jobs);
    const status = all.some((j) => j.status === "failed") ? "failed" : all.some((j) => j.status === "running" || j.status === "pending") ? "running" : "success";
    return { id: null, status, url: null, groups };
  }
  const list = await gl(repo, `${glp(repo, n)}/pipelines?per_page=1`).then(JSON.parse);
  if (!list.length) return null;
  const p = list[0], project = encodeURIComponent(repo.repo);
  return { id: p.id, status: JOB[p.status] ?? p.status, url: p.web_url, groups: await gitlabJobs(repo, project, p.id) };
}

export function retryJob(repo, job) {
  if (repo.provider === "github") return gh(repo, ["run", "rerun", String(job.run), "--job", String(job.id), ...ghR(repo)]);
  return gl(repo, `projects/${job.project}/jobs/${job.id}/${job.manual ? "play" : "retry"}`, ["-X", "POST"]);
}

export function cancelJob(repo, job) {
  if (repo.provider === "github") return gh(repo, ["run", "cancel", String(job.run), ...ghR(repo)]);
  return gl(repo, `projects/${job.project}/jobs/${job.id}/cancel`, ["-X", "POST"]);
}

// Re-runs what failed: GitLab retries the pipeline's failed jobs; GitHub each failed run.
export async function retryPipeline(repo, p) {
  if (repo.provider === "github") {
    const runs = [...new Set(p.groups.flatMap((g) => g.jobs).filter((j) => j.status === "failed" && j.run).map((j) => j.run))];
    for (const run of runs) await gh(repo, ["run", "rerun", run, "--failed", ...ghR(repo)]);
    return;
  }
  return gl(repo, `projects/${encodeURIComponent(repo.repo)}/pipelines/${p.id}/retry`, ["-X", "POST"]);
}

// The end of a job's log (for the agent).
export async function jobLogTail(repo, job, lines = 150) {
  const text = repo.provider === "github"
    ? await gh(repo, ["run", "view", "--job", String(job.id), "--log", ...ghR(repo)])
    : await gl(repo, `projects/${job.project}/jobs/${job.id}/trace`);
  // eslint-disable-next-line no-control-regex
  return text.replace(/\x1b\[[0-9;]*[A-Za-z]/g, "").replace(/\r/g, "").split("\n")
    // GitLab's timestamped logs: "2026-11-03T07:42:37.63Z 00O <text>"; section markers carry no text.
    .map((l) => l.replace(/^\d{4}-\d\d-\d\dT[\d:.]+Z \d{2}[OE]\+? ?/, "").replace(/section_(start|end):\d+:[A-Za-z0-9_.-]+(\[[^\]]*\])?/g, ""))
    .filter((l) => l.trim()).slice(-lines).join("\n");
}

// A shell command that shows a job's log in a terminal.
export function jobLogArgv(repo, job) {
  if (repo.provider === "github") return ["sh", "-c", `gh run view --job ${job.id} --log -R ${repo.host}/${repo.repo} | less -R`];
  return ["sh", "-c", `glab api --hostname ${repo.host} projects/${job.project}/jobs/${job.id}/trace | less -R`];
}

// ---- merge status, merging, draft, labels / assignees / reviewers ----
//
// status(repo, n) -> { title, state, draft, blockers: [text], conflicts, behind, autoMerge,
//   squash, removeBranch, labels: [name], assignees: [user], reviewers: [user], mergeable }
const GITLAB_BLOCK = {
  conflict: "Has merge conflicts", ci_must_pass: "The pipeline must succeed first", ci_still_running: "The pipeline is still running",
  discussions_not_resolved: "Unresolved threads", not_approved: "Needs approval", draft_status: "It's a draft",
  need_rebase: "Needs a rebase onto the target", blocked_status: "Blocked by another merge request", requested_changes: "Changes were requested",
  not_open: "Not open", merge_request_blocked: "Blocked by another merge request", jira_association_missing: "Needs a Jira issue key",
  checking: "GitLab is still checking", unchecked: "GitLab is still checking", preparing: "GitLab is still preparing it",
  commits_status: "Commit status checks haven't passed", security_policy_violations: "Security policy violations",
};
const GITHUB_BLOCK = {
  DIRTY: "Has merge conflicts", BEHIND: "Behind the target branch", BLOCKED: "Blocked by required reviews or checks",
  UNSTABLE: "Some checks are failing", DRAFT: "It's a draft", UNKNOWN: "GitHub is still checking",
};
export const blockerText = (provider, code) => {
  const c = String(code ?? "");
  if (provider === "github") return GITHUB_BLOCK[c] ?? null;
  return c.toLowerCase() === "mergeable" ? null : (GITLAB_BLOCK[c.toLowerCase()] ?? c.toLowerCase().replace(/_/g, " "));
};

export async function status(repo, n) {
  if (repo.provider === "github") {
    const p = JSON.parse(await gh(repo, ["pr", "view", String(n), ...ghR(repo), "--json",
      "title,state,isDraft,mergeable,mergeStateStatus,labels,assignees,reviewRequests,autoMergeRequest,reviewDecision,statusCheckRollup"]));
    const checks = (p.statusCheckRollup ?? []).map((c) => String(c.conclusion || c.state || c.status || "").toUpperCase());
    const ci = !checks.length ? null : checks.some((c) => ["FAILURE", "ERROR", "TIMED_OUT", "ACTION_REQUIRED"].includes(c)) ? "failed"
      : checks.some((c) => ["PENDING", "IN_PROGRESS", "QUEUED", "EXPECTED", "WAITING"].includes(c)) ? "running" : "success";
    const blockers = [blockerText("github", p.mergeStateStatus), p.reviewDecision === "CHANGES_REQUESTED" && "Changes were requested",
      p.reviewDecision === "REVIEW_REQUIRED" && "Needs an approving review"].filter(Boolean);
    return {
      title: p.title, state: p.state.toLowerCase(), draft: p.isDraft, blockers: [...new Set(blockers)], ci,
      conflicts: p.mergeable === "CONFLICTING", behind: p.mergeStateStatus === "BEHIND" ? true : 0,
      autoMerge: Boolean(p.autoMergeRequest), squash: true, removeBranch: true,
      labels: p.labels.map((l) => l.name), assignees: p.assignees.map((a) => a.login),
      reviewers: p.reviewRequests.map((r) => r.login ?? r.name).filter(Boolean),
      mergeable: ["CLEAN", "UNSTABLE", "HAS_HOOKS"].includes(p.mergeStateStatus),
    };
  }
  const m = JSON.parse(await gl(repo, `${glp(repo, n)}?include_diverged_commits_count=true`));
  const block = blockerText("gitlab", m.detailed_merge_status);
  return {
    title: m.title, state: m.state, draft: Boolean(m.draft), blockers: block ? [block] : [], ci: CI[String(m.head_pipeline?.status ?? "").toUpperCase()] ?? null,
    conflicts: Boolean(m.has_conflicts), behind: m.diverged_commits_count ?? 0,
    autoMerge: Boolean(m.merge_when_pipeline_succeeds), squash: Boolean(m.squash), removeBranch: Boolean(m.force_remove_source_branch),
    labels: m.labels ?? [], assignees: (m.assignees ?? []).map((a) => a.username), reviewers: (m.reviewers ?? []).map((a) => a.username),
    mergeable: m.detailed_merge_status === "mergeable",
  };
}

// opts: { squash, removeBranch, auto } (auto: merge when the pipeline succeeds)
export async function merge(repo, n, { squash, removeBranch, auto }) {
  if (repo.provider === "github") {
    return gh(repo, ["pr", "merge", String(n), ...ghR(repo), squash ? "--squash" : "--merge", ...(removeBranch ? ["--delete-branch"] : []), ...(auto ? ["--auto"] : [])]);
  }
  return send(repo, "PUT", `${glp(repo, n)}/merge`, { squash, should_remove_source_branch: removeBranch, ...(auto ? { merge_when_pipeline_succeeds: true } : {}) });
}

export function cancelAutoMerge(repo, n) {
  if (repo.provider === "github") return gh(repo, ["pr", "merge", String(n), ...ghR(repo), "--disable-auto"]);
  return gl(repo, `${glp(repo, n)}/cancel_merge_when_pipeline_succeeds`, ["-X", "POST"]);
}

export function setDraft(repo, n, title, draft) {
  if (repo.provider === "github") return gh(repo, ["pr", "ready", String(n), ...ghR(repo), ...(draft ? ["--undo"] : [])]);
  const bare = title.replace(/^\s*(\[draft\]|draft:|\(draft\))\s*/i, "");
  return send(repo, "PUT", glp(repo, n), { title: draft ? `Draft: ${bare}` : bare });
}

async function gitlabUserIds(repo, names) {
  const ids = [];
  for (const u of names) {
    const found = JSON.parse(await gl(repo, `users?username=${encodeURIComponent(u.replace(/^@/, ""))}`));
    if (!found.length) throw new Error(`No GitLab user @${u.replace(/^@/, "")}`);
    ids.push(found[0].id);
  }
  return ids;
}

// what: "label" | "assignee" | "reviewer"; current: the list now (GitLab replaces whole lists).
export async function editPeople(repo, n, what, { add = [], remove = [], current = [] }) {
  if (repo.provider === "github") {
    const flag = { label: "label", assignee: "assignee", reviewer: "reviewer" }[what];
    const args = [...add.flatMap((x) => [`--add-${flag}`, x.replace(/^@/, "")]), ...remove.flatMap((x) => [`--remove-${flag}`, x.replace(/^@/, "")])];
    return gh(repo, ["pr", "edit", String(n), ...ghR(repo), ...args]);
  }
  if (what === "label") return send(repo, "PUT", glp(repo, n), { add_labels: add.join(","), remove_labels: remove.join(",") });
  const strip = (u) => u.replace(/^@/, "");
  const names = [...new Set([...current.filter((u) => !remove.map(strip).includes(u)), ...add.map(strip)])];
  const ids = await gitlabUserIds(repo, names);
  return send(repo, "PUT", glp(repo, n), what === "assignee" ? { assignee_ids: ids } : { reviewer_ids: ids });
}
