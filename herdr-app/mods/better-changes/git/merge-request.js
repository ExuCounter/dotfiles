// The open GitLab merge request for a branch and its review threads, through glab on this
// machine with its own login. The Branch section compares HEAD with the request's target.
import { exec } from "herdr";
import { toThread } from "./review-queue.js";

// git@host:group/repo.git and https://host/group/repo(.git) -> { host, repo }.
export function gitlabRemote(url) {
  const text = (url ?? "").trim();
  const match =
    /^[\w.-]+@([^:/]+):(.+?)(?:\.git)?\/?$/.exec(text) ??
    /^\w+:\/\/(?:[^@/]+@)?([^/:]+)(?::\d+)?\/(.+?)(?:\.git)?\/?$/.exec(text);
  if (!match || /github/i.test(match[1])) return null;
  return { host: match[1], repo: match[2] };
}

// Tries the usual install folders when PATH doesn't have glab; only a program that couldn't
// start moves on, so a failed call is the answer.
async function glab(host, path, args = []) {
  for (const bin of ["glab", "/opt/homebrew/bin/glab", "/usr/local/bin/glab"]) {
    let result;
    try {
      result = await exec(bin, ["api", "--hostname", host, ...args, path]);
    } catch {
      continue;
    }
    if (result.code === 127) continue;
    if (result.code !== 0) throw new Error((result.stderr || result.stdout || "glab failed").trim());
    return result.stdout;
  }
  throw new Error("glab isn't installed");
}

// What GitLab needs from the person before it answers: a glab login, or for git over SSH a
// new SSO session at the URL GitLab names. Null for any other failure.
export function accessProblem(text) {
  const sso = /Cannot find valid SSO session[\s\S]*?(https:\/\/\S+\/saml\/sso\S*)/.exec(text ?? "");
  if (sso) return { kind: "sso", url: sso[1] };
  if (/401|unauthori[sz]ed|not logged in|glab auth login|no token/i.test(text ?? "")) return { kind: "login" };
  return null;
}

// Whether glab's login still works on the host.
export async function glabProblem(host) {
  try {
    await glab(host, "user");
    return null;
  } catch (e) {
    return accessProblem(e.message);
  }
}

const requestPath = (mr) =>
  `projects/${encodeURIComponent(mr.repo)}/merge_requests/${mr.iid}`;

export async function findMergeRequest(remote, branch) {
  const base = `projects/${encodeURIComponent(remote.repo)}/merge_requests`;
  const found = JSON.parse(
    await glab(remote.host, `${base}?source_branch=${encodeURIComponent(branch)}&state=opened&per_page=5`),
  );
  const mr = found[0];
  if (!mr) return null;
  return {
    iid: mr.iid,
    url: mr.web_url,
    title: mr.title,
    target: mr.target_branch,
    author: mr.author?.id,
    host: remote.host,
    repo: remote.repo,
  };
}

// Discussions with a note from a person, oldest first.
// glab prints one JSON array per page back to back, so pages come one item per line.
export async function readThreads(mr) {
  const out = await glab(mr.host, `${requestPath(mr)}/discussions?per_page=100`, [
    "--paginate",
    "--output",
    "ndjson",
  ]);
  return out
    .split("\n")
    .filter((line) => line.trim())
    .map((line) => toThread(JSON.parse(line)))
    .filter(Boolean);
}

// The glab login's user id on the host, read once.
const users = new Map();
export function readMe(host) {
  if (!users.has(host))
    users.set(
      host,
      glab(host, "user").then(
        (out) => JSON.parse(out).id,
        (e) => {
          users.delete(host);
          throw e;
        },
      ),
    );
  return users.get(host);
}

export function replyToThread(mr, thread, body) {
  return glab(mr.host, `${requestPath(mr)}/discussions/${thread.id}/notes`, ["-X", "POST", "-f", `body=${body}`]);
}

export function resolveThread(mr, thread, resolved) {
  return glab(mr.host, `${requestPath(mr)}/discussions/${thread.id}?resolved=${resolved}`, ["-X", "PUT"]);
}

// A JSON body goes through stdin: glab's -f flags can't nest the draft's position.
async function glabJSON(host, method, path, body) {
  const result = await exec("/bin/sh", [
    "-c",
    'PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"; printf %s "$1" | glab api --hostname "$2" -X "$3" -H "Content-Type: application/json" --input - "$4"',
    "sh",
    JSON.stringify(body ?? {}),
    host,
    method,
    path,
  ]);
  if (result.code !== 0) throw new Error((result.stderr || result.stdout || "glab failed").trim());
  return result.stdout ? JSON.parse(result.stdout) : null;
}

// The shas GitLab anchors line comments to, for the request's latest version.
export async function diffRefs(mr) {
  return JSON.parse(await glab(mr.host, requestPath(mr))).diff_refs;
}

// GitLab names a diff line by its file's SHA-1 and both sides' line numbers.
export async function pathHash(path) {
  const result = await exec("/bin/sh", ["-c", 'printf %s "$1" | shasum | cut -c1-40', "sh", path]);
  return result.stdout.trim();
}

// A new thread on the request, on its line when there's a position.
export function createDiscussion(mr, body, position) {
  return glabJSON(mr.host, "POST", `${requestPath(mr)}/discussions`, position ? { body, position } : { body });
}

export function createDraft(mr, note, position) {
  return glabJSON(mr.host, "POST", `${requestPath(mr)}/draft_notes`, position ? { note, position } : { note });
}

export function deleteDraft(mr, id) {
  return glab(mr.host, `${requestPath(mr)}/draft_notes/${id}`, ["-X", "DELETE"]);
}

export function publishDrafts(mr) {
  return glab(mr.host, `${requestPath(mr)}/draft_notes/bulk_publish`, ["-X", "POST"]);
}

export function approve(mr) {
  return glab(mr.host, `${requestPath(mr)}/approve`, ["-X", "POST"]);
}
