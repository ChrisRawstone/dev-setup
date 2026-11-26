#!/usr/bin/env python3
"""Health watchdog for this Mac. Notifies only; the one exception is a stuck Spotify, which it restarts.

Run every 15 min by launchd (launchd/com.rawstone.mac-watchdog.plist). Posts a macOS
notification (and logs it) when:
  - one process uses more than 8 GB of memory (incl. compressed/swapped; e.g. Herdr's GPU leak)
  - one process stays above 90% CPU for 3 runs in a row (e.g. a stuck BTLEServer);
    security agents the user can't touch are left out. Spotify's renderer (a known hang) is restarted
    after 2 runs instead, resuming playback if it was playing
  - uptime is over 7 days and swap use is over 8 GB (restart nudge)
  - once a day: Wi-Fi/Bluetooth woke the Mac more than 10 times per hour asleep in the last 24 h
The same alert repeats at most every 6 h. State lives in ~/.local/state/mac-watchdog.json.

  mac-watchdog.py            # check and notify
  mac-watchdog.py --dry-run  # print what it would notify, change no state
"""
import json, os, re, subprocess, sys, time

STATE = os.path.expanduser("~/.local/state/mac-watchdog.json")
MEM_GB, CPU_PCT, CPU_RUNS = 8, 90, 3
UPTIME_DAYS, SWAP_GB = 7, 8
WAKES_PER_HOUR = 10
COOLDOWN = 6 * 3600
# Work security agents: high CPU is normal for them and nothing can be done locally.
IGNORE = re.compile(r"epsext|wdavdaemon|defendpoint|beyondtrust|interrogator|dlpdaemon|dgdaemon|dgesc|"
                    r"nxtsvc|nexthink|tanium|kernel_task|mac-watchdog", re.I)
DRY = "--dry-run" in sys.argv


def sh(*cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def size_gb(s):
    m = re.match(r"([\d.]+)([BKMGT])", s)
    return float(m.group(1)) * {"B": 1e-9, "K": 1e-6, "M": 1e-3, "G": 1, "T": 1e3}[m.group(2)] if m else 0


def checks(state):
    alerts = []
    # 1. memory hogs (top's MEM includes compressed and swapped pages, unlike RSS)
    for line in sh("top", "-l", "1", "-o", "mem", "-n", "5", "-stats", "pid,mem,command").splitlines():
        m = re.match(r"\s*(\d+)\s+(\S+)\s+(.+)$", line)
        if m and size_gb(m.group(2)) > MEM_GB and not IGNORE.search(m.group(3)):
            name = m.group(3).strip()
            alerts.append((f"mem:{name}", f"{name} uses {m.group(2)} memory",
                           "Restart it to free the memory." + (" (Herdr GPU leak, herdr#5783)" if "Herdr" in name else "")))

    # 2. sustained CPU, tracked per pid across runs
    streaks, now_hot = state.get("cpu", {}), {}
    for line in sh("ps", "-Ao", "pid=,pcpu=,comm=").splitlines():
        pid, cpu, comm = line.split(None, 2)
        name = os.path.basename(comm)
        if float(cpu) >= CPU_PCT and not IGNORE.search(comm):
            now_hot[pid] = streaks.get(pid, 0) + 1
            if name == "Spotify Helper (Renderer)" and now_hot[pid] >= 2:
                if not DRY:
                    restart_spotify()
                alerts.append(("spotify", f"Spotify was stuck at {cpu}% CPU", "Restarted it automatically."))
            elif now_hot[pid] >= CPU_RUNS:
                hint = "Bluetooth stuck: run `sudo killall BTLEServer`." if name.startswith("BTLE") or name == "bluetoothd" \
                    else "Quit or restart it if you're not using it."
                alerts.append((f"cpu:{name}", f"{name} at {cpu}% CPU for {now_hot[pid] * 15}+ min", hint))
    state["cpu"] = now_hot

    # 3. restart nudge
    boot = int(re.search(r"sec = (\d+)", sh("sysctl", "-n", "kern.boottime")).group(1))
    days = (time.time() - boot) / 86400
    swap = re.search(r"used = ([\d.]+)M", sh("sysctl", "-n", "vm.swapusage"))
    swap_gb = float(swap.group(1)) / 1024 if swap else 0
    if days > UPTIME_DAYS and swap_gb > SWAP_GB:
        alerts.append(("restart", f"Up {days:.0f} days, {swap_gb:.0f} GB swap", "Restart the Mac to clear swap."))

    # 4. once a day: Wi-Fi/Bluetooth wakes while asleep (parsing pmset's log costs a few CPU seconds)
    today = time.strftime("%Y-%m-%d")
    if state.get("wakes_checked") != today:
        state["wakes_checked"] = today
        since = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(time.time() - 86400))
        asleep = wakes = 0
        for line in sh("pmset", "-g", "log").splitlines():
            if line[:19] < since:
                continue
            if re.match(r"\S+ \S+ \S+ Sleep\s", line):
                m = re.search(r"(\d+) secs", line)
                asleep += int(m.group(1)) if m else 0
            elif " DarkWake " in line and "wifibt" in line:
                wakes += 1
        hours = asleep / 3600
        if hours > 2 and wakes / hours > WAKES_PER_HOUR:
            alerts.append(("wakes", f"Wi-Fi/Bluetooth woke the Mac {wakes / hours:.0f}×/h asleep",
                           "Battery drain. Restart Bluetooth (`sudo killall BTLEServer`) or the Mac."))
    return alerts


def restart_spotify():
    tell = lambda cmd: subprocess.run(["osascript", "-e", f'tell application "Spotify" to {cmd}'],
                                      capture_output=True, text=True, timeout=20).stdout.strip()
    try:
        playing = tell("player state as string") == "playing"
        tell("quit")
    except subprocess.TimeoutExpired:
        playing = False
    for _ in range(15):
        if subprocess.run(["pgrep", "-x", "Spotify"], capture_output=True).returncode:
            break
        time.sleep(1)
    else:
        subprocess.run(["pkill", "-9", "-x", "Spotify"])
        time.sleep(2)
    subprocess.run(["open", "-g", "-a", "Spotify"])
    if playing:
        time.sleep(8)
        tell("play")


def notify(title, body):
    esc = lambda s: s.replace("\\", "\\\\").replace('"', '\\"')
    subprocess.run(["osascript", "-e", f'display notification "{esc(body)}" with title "Mac watchdog" subtitle "{esc(title)}"'])


def main():
    try:
        state = json.load(open(STATE))
    except (OSError, ValueError):
        state = {}
    sent = state.setdefault("sent", {})
    stamp = time.strftime("%Y-%m-%d %H:%M")
    for key, title, body in checks(state):
        if time.time() - sent.get(key, 0) < COOLDOWN and not DRY:
            continue
        print(f"{stamp} {title}. {body}", flush=True)
        if not DRY:
            notify(title, body)
            sent[key] = time.time()
    if not DRY:
        os.makedirs(os.path.dirname(STATE), exist_ok=True)
        json.dump(state, open(STATE, "w"))


if __name__ == "__main__":
    main()
