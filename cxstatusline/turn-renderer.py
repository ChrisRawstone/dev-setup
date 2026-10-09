#!/usr/bin/env python3
"""Add an observed per-turn timer to cxstatusline's local renderer. No network."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

def find_renderer():
    """Locate cxstatusline's JS entry and a node to run it, wherever npm put them
    (Homebrew's node or any nvm version). The node next to the package wins."""
    candidates = []
    binary = shutil.which('cxstatusline')
    if binary:
        candidates.append(Path(os.path.realpath(binary)).parent / 'cxstatusline.js')
    candidates += sorted(Path('__HOME__/.nvm/versions/node').glob('*/lib/node_modules/cxstatusline/dist/cxstatusline.js'), reverse=True)
    candidates.append(Path('/opt/homebrew/lib/node_modules/cxstatusline/dist/cxstatusline.js'))
    for js in candidates:
        if js.is_file():
            # <prefix>/lib/node_modules/cxstatusline/dist/cxstatusline.js -> <prefix>/bin/node
            node = js.parents[4] / 'bin' / 'node'
            return str(node if node.exists() else (shutil.which('node') or 'node')), str(js)
    return shutil.which('node') or 'node', str(candidates[-1])

NODE, RENDERER = find_renderer()
STATE_ROOT = Path('__HOME__/.local/state/cxstatusline/turn-timers')
PLACEHOLDER = 'turn —'

def update_timer(previous, running, now):
    state = dict(previous)
    if running and not state.get('running'):
        state['start'] = now
        state['elapsed'] = 0
    if state.get('start') is not None:
        if running or state.get('running'):
            state['elapsed'] = max(0, now - state['start'])
    state['running'] = running
    return state

def duration(seconds):
    seconds = int(max(0, seconds))
    hours, rest = divmod(seconds, 3600)
    minutes, seconds = divmod(rest, 60)
    return f'{hours}h{minutes:02}m{seconds:02}s' if hours else f'{minutes}m{seconds:02}s' if minutes else f'{seconds}s'

def main():
    raw = sys.stdin.buffer.read(65537)
    if len(raw) > 65536:
        return 2
    data = json.loads(raw)
    session = data.get('session') or {}
    state = {}
    identity = str(session.get('id') or '')
    if identity:
        key = hashlib.sha256((identity + '\0' + str(session.get('started_at') or '')).encode()).hexdigest()
        STATE_ROOT.mkdir(parents=True, exist_ok=True, mode=0o700)
        if STATE_ROOT.is_symlink():
            return 2
        file = STATE_ROOT / (key + '.json')
        if file.is_symlink():
            return 2
        try:
            state = json.loads(file.read_text())
        except (FileNotFoundError, ValueError):
            pass
        run_state = str(session.get('run_state') or '').lower()
        running = run_state in ('working', 'thinking', 'running', 'compacting', 'compacting context')
        state = update_timer(state, running, time.time())
        temp = file.with_suffix('.' + str(os.getpid()) + '.tmp')
        fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w') as handle:
            json.dump(state, handle)
        os.replace(temp, file)
    env = dict(os.environ, DEV='false')
    result = subprocess.run([NODE, RENDERER, 'render'], input=raw, capture_output=True, timeout=0.85, env=env)
    if result.returncode:
        return result.returncode
    text = result.stdout.decode('utf-8')
    label = 'turn ' + duration(state['elapsed']) if state.get('start') is not None else PLACEHOLDER
    sys.stdout.write(text.replace(PLACEHOLDER, label))
    return 0

if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.TimeoutExpired):
        sys.exit(2)
