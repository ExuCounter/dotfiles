// Listening TCP ports on each machine that holds spaces, matched to the worktree spaces they run in.
import { exec, readTextFile } from "herdr";

export const SHARED_KEY = "live-ports";

// Keyed by machine as well: pids and folders mean different things on different machines.
const key = (on, x) => JSON.stringify([on, x]);
const cwds = new Map(); // [machine, pid] -> cwd; a server's folder doesn't change while it runs
const roots = new Map(); // [machine, folder] -> git toplevel, or null outside a repo
const wsl = new Map(); // machine -> whether it is WSL (its localhost reaches Windows' localhost)

// `lsof -F` records: p<pid>, c<command>, n<address>.
function parseListeners(out) {
  const seen = new Map();
  let pid = null;
  let name = null;
  for (const line of out.split(/\r?\n/)) {
    const tag = line[0];
    const value = line.slice(1);
    if (tag === "p") pid = Number(value);
    else if (tag === "c") name = value;
    else if (tag === "n") {
      const m = value.match(/^(.*):(\d+)$/);
      if (!m || !pid) continue;
      const port = Number(m[2]);
      const key = `${pid}:${port}`;
      if (!seen.has(key)) seen.set(key, { pid, port, name, host: m[1] });
    }
  }
  return [...seen.values()].sort((a, b) => a.port - b.port);
}

// Linux without lsof: `ss -ltnpH` lines (`LISTEN 0 5 127.0.0.1:5173 0.0.0.0:* users:(("node",pid=12,fd=3))`)
// rewritten as lsof records, so one parser reads both.
function ssToLsof(out) {
  const records = [];
  for (const line of out.split(/\r?\n/)) {
    const local = line.trim().split(/\s+/)[3];
    for (const m of line.matchAll(/\("([^"]*)",pid=(\d+)/g)) records.push(`p${m[2]}`, `c${m[1]}`, `n${local}`);
  }
  return records.join("\n");
}

async function listeners(on) {
  const r = await exec("lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcn"], { on }).catch(() => null);
  if (r) return parseListeners(r.stdout);
  const ss = await exec("ss", ["-ltnpH"], { on });
  return parseListeners(ssToLsof(ss.stdout));
}

async function loadCwds(on, pids) {
  const missing = pids.filter((p) => !cwds.has(key(on, p)));
  if (!missing.length) return;
  const r = await exec("lsof", ["-a", "-d", "cwd", "-F", "n", "-p", missing.join(",")], { on })
    // No lsof: the same records from /proc.
    .catch(() => exec("sh", ["-c", 'for p; do printf "p%s\\nn%s\\n" "$p" "$(readlink "/proc/$p/cwd")"; done', "sh", ...missing.map(String)], { on }));
  let pid = null;
  for (const line of r.stdout.split(/\r?\n/)) {
    if (line[0] === "p") pid = Number(line.slice(1));
    else if (line[0] === "n" && pid && line.length > 1) cwds.set(key(on, pid), line.slice(1));
  }
  for (const p of missing) if (!cwds.has(key(on, p))) cwds.set(key(on, p), null);
}

async function gitRoot(on, folder) {
  const k = key(on, folder);
  if (roots.has(k)) return roots.get(k);
  const r = await exec("git", ["rev-parse", "--show-toplevel"], { cwd: folder, on }).catch(() => null);
  const root = r?.code === 0 ? r.stdout.trim() : null;
  roots.set(k, root);
  return root;
}

// A WSL machine's loopback ports are forwarded to Windows' localhost (WSL's default), so a
// Windows app can open them; any other machine's localhost isn't this computer's.
async function isWsl(on) {
  if (wsl.has(on)) return wsl.get(on);
  // null means no such file (a machine without /proc is not WSL); only a rejected read is asked again.
  const text = await readTextFile("/proc/sys/kernel/osrelease", { on }).catch(() => undefined);
  const is = /microsoft|wsl/i.test(text ?? "");
  if (text !== undefined) wsl.set(on, is);
  return is;
}

const inside = (path, root) => path === root || path.startsWith(`${root}/`);

// Every space on machine `on` whose terminals sit in a git checkout, by checkout root.
async function spaceRoots(on, spaceList, paneList) {
  const out = [];
  for (const s of spaceList) {
    if ((s.machine ?? null) !== on) continue;
    const tabs = new Set((s.tabs ?? []).map((t) => t.id));
    const folders = new Set([s.folder, ...paneList.filter((p) => tabs.has(p.tab)).map((p) => p.cwd)]);
    for (const f of folders) {
      const root = f && (await gitRoot(on, f));
      if (root && !out.some((o) => o.root === root)) out.push({ space: s.id, name: s.name, root });
    }
  }
  return out.sort((a, b) => b.root.length - a.root.length); // deepest checkout wins
}

async function scanMachine(on, spaceList, paneList, appOnWindows) {
  const bySpace = {};
  const external = [];
  const found = await listeners(on);
  const live = new Set(found.map((l) => key(on, l.pid)));
  for (const k of cwds.keys()) if (JSON.parse(k)[0] === on && !live.has(k)) cwds.delete(k);
  await loadCwds(on, [...new Set(found.map((l) => l.pid))]);

  const owners = await spaceRoots(on, spaceList, paneList);
  const reachable = on === null || (appOnWindows && (await isWsl(on)));
  for (const l of found) {
    const cwd = cwds.get(key(on, l.pid));
    const owner = cwd && owners.find((o) => inside(cwd, o.root));
    const port = { port: l.port, pid: l.pid, name: l.name ?? `PID ${l.pid}`, address: `localhost:${l.port}`, machine: on, reachable };
    if (owner) (bySpace[owner.space] ??= []).push(port);
    else external.push(port);
  }
  return { bySpace, external };
}

// Scans every machine that holds spaces (skipping ones machines() reports unavailable), and this
// computer unless the app runs on Windows, which has no lsof. Machines are scanned in parallel, so a
// slow one doesn't hold up the rest; one that fails keeps its ports from `previous` (the last result).
export async function scanPorts(spaceList, paneList, machineList, platform, previous) {
  const down = new Set(machineList.filter((m) => m.layout === "unavailable").map((m) => m.name));
  const targets = new Set(spaceList.map((s) => s.machine ?? null).filter((on) => on !== null && !down.has(on)));
  if (platform !== "windows") targets.add(null);
  const order = [null, ...[...targets].filter(Boolean).sort()].filter((on) => targets.has(on));
  const results = await Promise.allSettled(order.map((on) => scanMachine(on, spaceList, paneList, platform === "windows")));
  const bySpace = {};
  const external = [];
  order.forEach((on, i) => {
    let r = results[i].value;
    if (results[i].status === "rejected") {
      console.warn(`live-ports: scanning ${on ?? "this computer"} failed: ${results[i].reason}`);
      const mine = (l) => (l ?? []).filter((p) => (p.machine ?? null) === on);
      r = {
        bySpace: Object.fromEntries(Object.entries(previous?.bySpace ?? {}).map(([k, l]) => [k, mine(l)])),
        external: mine(previous?.external),
      };
    }
    for (const [k, l] of Object.entries(r.bySpace)) if (l.length) (bySpace[k] ??= []).push(...l);
    external.push(...r.external);
  });
  return { bySpace, external };
}

// null when the port can't be opened from this computer (a loopback port on another machine).
export const portUrl = (p) => (p.reachable === false ? null : `http://${p.address}`);
