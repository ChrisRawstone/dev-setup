#!/usr/bin/env python3
"""Hook for Claude Code and Codex. PostToolUse/PostToolUseFailure: when a fetch looks bot-blocked, remind the agent
to use the blocked-fetch skill instead of giving up. PreToolUse on WebFetch: if fetch.py already had to get this site
(it remembers sites in ~/.cache/blocked-fetch/domains.json), skip the doomed WebFetch and point at fetch.py."""
import json, re, sys
from pathlib import Path
from urllib.parse import urlsplit

SIGNS = re.compile(
    r"\b(403|429)\b|Forbidden|Too Many Requests|Just a moment|cf-chl|challenge-platform|Security Checkpoint"
    r"|Access Denied|Access to this page has been denied|captcha|datadome|px-captcha|Pardon Our Interruption"
    r"|unusual traffic|Are you a robot|blocked|STILL BLOCKED", re.I)
FETCHY = re.compile(r"\b(curl|wget|http|requests|httpx|fetch|playwright|agent-browser)\b", re.I)
HINT = ("This fetch looks bot-blocked (403/429/challenge/captcha). Don't give up or call the page unreadable: "
        "run uv run -q ~/.claude/skills/blocked-fetch/fetch.py 'URL' --grep 'WHAT YOU NEED' (curl_cffi fingerprints, "
        "headless Chrome, Apify), then the blocked-fetch skill's other steps (archive copy, Codex).")


def hint(d):
    tool = d.get("tool_name", "")
    out = json.dumps([d.get("tool_response"), d.get("error")], default=str)
    if tool == "WebFetch":
        return bool(SIGNS.search(out))
    if tool in ("Bash", "shell", "local_shell", "exec_command"):
        cmd = json.dumps(d.get("tool_input", {}))
        # Status codes alone are too common in shell output; there, need a fetch command and a specific sign.
        return bool(FETCHY.search(cmd)) and bool(re.search(
            r"HTTP/[\d.]+ (403|429|503)|\b(403|429) (Forbidden|Too Many)|STILL BLOCKED|Just a moment|cf-chl"
            r"|Security Checkpoint|Access to this page has been denied|px-captcha|captcha-delivery", out, re.I))
    return False


def known_blocked(d):
    host = urlsplit(str(d.get("tool_input", {}).get("url", ""))).hostname
    try:
        return host and host in json.loads((Path.home() / ".cache/blocked-fetch/domains.json").read_text())
    except (OSError, ValueError):
        return False


def main():
    try:
        d = json.load(sys.stdin)
    except ValueError:
        return
    if d.get("hook_event_name") == "PreToolUse":
        if d.get("tool_name") == "WebFetch" and known_blocked(d):
            url = d["tool_input"]["url"]
            print(json.dumps({"hookSpecificOutput": {
                "hookEventName": "PreToolUse", "permissionDecision": "deny",
                "permissionDecisionReason": "This site blocks plain fetches (blocked-fetch remembers it). Run instead: "
                f"uv run -q ~/.claude/skills/blocked-fetch/fetch.py '{url}' --grep 'WHAT YOU NEED'"}}))
        return
    if hint(d):
        print(json.dumps({"hookSpecificOutput": {"hookEventName": d.get("hook_event_name", "PostToolUse"),
                                                 "additionalContext": HINT}}))


if __name__ == "__main__":
    main()
