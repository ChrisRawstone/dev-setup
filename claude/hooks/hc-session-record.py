#!/usr/bin/env python3
"""Remember which Claude session runs in which herdr-app terminal, so claude-restore can
resume it after a reboot. SessionStart writes ~/.local/state/claude-hc-sessions/<terminal>,
a clean SessionEnd deletes it; a reboot kills Claude without SessionEnd, so the file stays.
Only for terminals started by herdr-app (HC_TERMINAL_ID set)."""
import json, os, sys

term = os.environ.get("HC_TERMINAL_ID")
try:
    hook = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
if not term or hook.get("agent_id") or not hook.get("session_id"):
    sys.exit(0)

path = os.path.join(os.path.expanduser("~/.local/state/claude-hc-sessions"), term)
if hook.get("hook_event_name") == "SessionStart":
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump({"session_id": hook["session_id"], "cwd": os.getcwd()}, f)
# Only a deliberate exit forgets it: "other" covers SIGTERM/SIGHUP at shutdown, and a
# /clear or resume starts a new session that overwrites the file anyway.
elif hook.get("hook_event_name") == "SessionEnd" and hook.get("reason") in ("prompt_input_exit", "logout"):
    try:
        if json.load(open(path)).get("session_id") == hook["session_id"]:
            os.remove(path)
    except (OSError, ValueError):
        pass
