#!/usr/bin/env python3
"""Stop local dev servers (and agent-browser daemons) that have been left running.

A dev server is any process listening on TCP whose working directory is under ~/Repos.
It is stopped when it is older than --max-age hours AND no claude/codex session is
working in the same project (same repo, or same .claude/worktrees/<name> worktree).
The whole job is stopped (vite + npm wrapper, uvicorn + reloader), never the shell
or Herdr pane it runs in. Run every 6 h by launchd (launchd/com.rawstone.reap-dev-servers.plist).

  reap-dev-servers.py              # stop servers older than 48 h
  reap-dev-servers.py --max-age 1  # stop servers older than 1 h
  reap-dev-servers.py --dry-run    # only print what would be stopped
"""
import argparse, os, re, signal, subprocess, time

HOME = os.path.expanduser("~")
REPOS = os.path.join(HOME, "Repos") + "/"
# Walking up from a server stops at these: they are the pane/session, not the job.
STOP_AT = re.compile(r"^-?(zsh|bash|fish|sh -l|login|launchd|tmux|herdr|Herdr|claude|codex|Cursor|Code)", re.I)
SESSIONS = re.compile(r"^(claude|codex)$")


def sh(*cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def processes():
    """pid -> (ppid, age_seconds, comm, command)"""
    procs = {}
    for line in sh("ps", "-Ao", "pid=,ppid=,etime=,comm=").splitlines():
        pid, ppid, etime, comm = line.split(None, 3)
        procs[int(pid)] = [int(ppid), etime_seconds(etime), os.path.basename(comm), ""]
    for line in sh("ps", "-Ao", "pid=,command=").splitlines():
        pid, _, cmd = line.strip().partition(" ")
        if int(pid) in procs:
            procs[int(pid)][3] = cmd
    return procs


def etime_seconds(e):
    days, _, rest = e.rpartition("-")
    parts = [int(p) for p in rest.split(":")]
    while len(parts) < 3:
        parts.insert(0, 0)
    h, m, s = parts
    return int(days or 0) * 86400 + h * 3600 + m * 60 + s


def cwds(pids):
    if not pids:
        return {}
    out, cur = {}, None
    for line in sh("lsof", "-a", "-d", "cwd", "-Fn", "-p", ",".join(map(str, pids))).splitlines():
        if line.startswith("p"):
            cur = int(line[1:])
        elif line.startswith("n") and cur:
            out[cur] = line[1:]
    return out


def project(path):
    """The repo or worktree a path belongs to, or None if outside ~/Repos."""
    if not path or not path.startswith(REPOS):
        return None
    m = re.match(r"(.*?/\.claude/worktrees/[^/]+)", path) or re.match(r"(.*?/\.worktrees/[^/]+)", path)
    if m:
        return m.group(1)
    rest = path[len(REPOS):].split("/")
    return REPOS + "/".join(rest[:2])


def descendants(pid, procs):
    kids = [p for p, v in procs.items() if v[0] == pid]
    return kids + [d for k in kids for d in descendants(k, procs)]


def job_root(pid, procs):
    """Highest ancestor that is still part of the server's job (not the shell/pane)."""
    while True:
        ppid = procs.get(pid, [1])[0]
        if ppid <= 1 or ppid not in procs or STOP_AT.match(procs[ppid][2]):
            return pid
        pid = ppid


def stop(pids, dry):
    if dry:
        return
    for p in pids:
        try: os.kill(p, signal.SIGTERM)
        except ProcessLookupError: pass
    time.sleep(3)
    for p in pids:
        try: os.kill(p, signal.SIGKILL)
        except ProcessLookupError: pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--max-age", type=float, default=48, help="hours (default 48)")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    limit = a.max_age * 3600
    procs = processes()

    listeners = {int(p) for p in sh("lsof", "-nP", "-iTCP", "-sTCP:LISTEN", "-t").split()}
    sessions = [p for p, v in procs.items() if SESSIONS.match(v[2])]
    cw = cwds(sorted(listeners | set(sessions)))
    busy = {project(cw.get(p)) for p in sessions} - {None}

    jobs = {}
    for pid in listeners:
        proj = project(cw.get(pid))
        if not proj or pid not in procs:
            continue
        root = job_root(pid, procs)
        jobs.setdefault(root, proj)

    # agent-browser daemons (and the Chrome they drive) left over from browser testing
    for pid, v in procs.items():
        if "agent-browser/bin/agent-browser" in v[3] and procs.get(v[0], [0, 0, ""])[2] != "agent-browser":
            jobs.setdefault(job_root(pid, procs), "agent-browser")

    stamp = time.strftime("%Y-%m-%d %H:%M")
    for root, proj in sorted(jobs.items()):
        age = procs[root][1]
        if age < limit or proj in busy:
            continue
        tree = [root] + descendants(root, procs)
        print(f"{stamp} {'would stop' if a.dry_run else 'stop'} {root} ({age // 3600} h) {proj.replace(HOME, '~')}: {procs[root][3][:100]}")
        stop(tree, a.dry_run)


if __name__ == "__main__":
    main()
