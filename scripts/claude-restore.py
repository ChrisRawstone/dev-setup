#!/usr/bin/env python3
"""Resume the Claude sessions that were running in herdr-app terminals when the Mac
restarted (or herdr-core died). Reads what claude/hooks/hc-session-record.py wrote and
types `claude --resume <id>` into each terminal that is back at a shell prompt.

Run at login by launchd (launchd/com.rawstone.claude-restore.plist), or by hand:
  claude-restore.py            # resume them
  claude-restore.py --dry-run  # only list them
"""
import glob, json, os, subprocess, sys, time

HC = os.path.expanduser("~/.local/bin/hc")
DIR = os.path.expanduser("~/.local/state/claude-hc-sessions")
SHELLS = {"zsh", "-zsh", "bash", "fish"}
DRY = "--dry-run" in sys.argv


def hc(*args):
    return subprocess.run([HC, *args], capture_output=True, text=True, timeout=20)


def main():
    files = sorted(glob.glob(os.path.join(DIR, "t*")))
    if not files:
        return
    for _ in range(60):  # at login herdr-core may still be starting: wait up to 5 min
        if hc("ls", "--json").returncode == 0:
            break
        time.sleep(5)
    time.sleep(10)  # let the shells in restored terminals finish starting
    stamp = time.strftime("%Y-%m-%d %H:%M")
    for path in files:
        term = os.path.basename(path)
        try:
            rec = json.load(open(path))
            t = json.loads(hc("get", term).stdout)
        except (OSError, ValueError):
            print(f"{stamp} {term}: terminal gone, dropping {path}")
            DRY or os.remove(path)
            continue
        fg = (t.get("foreground") or {}).get("name")
        if t.get("state") != "live" or fg not in SHELLS:
            print(f"{stamp} {term}: busy ({fg}), skipped")  # e.g. Claude already resumed there
            continue
        # A shell, so the user's `claude` function adds their usual flags.
        cmd = f"cd {json.dumps(rec['cwd'])} && claude --resume {rec['session_id']}"
        print(f"{stamp} {term}: {cmd}")
        if not DRY:
            hc("send", term, cmd)
            os.remove(path)  # the resumed session's SessionStart writes it again


if __name__ == "__main__":
    main()
