#!/usr/bin/python3 -I
"""PreToolUse(Bash) hook: in personal folders only, let `railway up` and `git push` skip the auto-mode classifier.

Approves a command only when it runs under ~/scratch or ~/Repos/personal, every `cd` / `git -C` target stays there,
and every piece is on the short list below. Anything else (force pushes, $(...), redirects, other commands) gets no
answer from this hook, so the normal permission checks and the classifier decide. Run with --selftest to check it.
"""
import json
import os
import re
import shlex
import sys

HOME = os.path.expanduser("~")
ROOTS = [os.path.join(HOME, "scratch"), os.path.join(HOME, "Repos", "personal")]
GIT_SUBS = {"push", "status", "log", "add", "commit", "diff"}
OPS = {"&&", "||", ";", "|"}


def inside(path):
    p = os.path.realpath(path)
    return any(p == r or p.startswith(r + os.sep) for r in ROOTS)


def resolve(target, cwd):
    if "$" in target:
        return None
    path = os.path.join(cwd, os.path.expanduser(target))
    return path if inside(path) else None


def risky_push(args):
    return any(
        "$" in a
        or a.startswith(("+", "--force", "--delete", "--mirror", "--prune"))
        or ":" in a  # src:dst and :delete refspecs, URLs
        or re.fullmatch(r"-[a-zA-Z]*[fd][a-zA-Z]*", a)
        for a in args
    )


def segment_ok(t, cwd):
    """Return the cwd after this segment, or None if the segment isn't on the list."""
    if t[0] == "cd" and len(t) == 2:
        return resolve(t[1], cwd)
    if t[:2] == ["railway", "up"]:
        return cwd
    if t[0] == "git":
        rest = t[1:]
        if rest[:1] == ["-C"] and len(rest) > 1:
            if not resolve(rest[1], cwd):
                return None
            rest = rest[2:]
        if not rest or rest[0] not in GIT_SUBS:
            return None
        if rest[0] == "push" and risky_push(rest[1:]):
            return None
        return cwd
    if t[0] in ("tail", "head") and all(re.fullmatch(r"-n?\d+|-n", a) or a.isdigit() for a in t[1:]):
        return cwd
    return None


def allowed(command, cwd):
    if not inside(cwd) or "`" in command or "$(" in command:
        return False
    command = command.replace("2>&1", "")
    if not re.search(r"(^|[\s;&|])(railway up|git (-C \S+ )?push)(\s|$)", command):
        return False
    for line in command.split("\n"):
        try:
            lex = shlex.shlex(line, posix=True, punctuation_chars=True)
            lex.whitespace_split = True
            tokens = list(lex)
        except ValueError:  # unbalanced quotes, e.g. a multi-line commit message
            return False
        seg = []
        for tok in tokens + [";"]:
            if tok in OPS:
                if seg:
                    cwd = segment_ok(seg, cwd)
                    if cwd is None:
                        return False
                seg = []
            elif set(tok) <= set("&|;<>()"):  # any other operator: &, >, <, (
                return False
            else:
                seg.append(tok)
    return True


def selftest():
    P = os.path.join(HOME, "Repos/personal/home-assistant/plants")
    W = os.path.join(HOME, "Repos/work/x")
    ok = [
        ("railway up -s plants --ci 2>&1 | tail -15", P),
        ('cd ~/Repos/personal/home-assistant/plants && railway up "$D" --path-as-root -s plants --ci 2>&1 | tail -15', HOME + "/scratch"),
        ("git push", P),
        ("git push -u origin feat/x", P),
        ('git add -A && git commit -m "fix: a; b && c" && git push origin main', P),
        ("git -C ~/Repos/personal/sites push origin main && git log -1", HOME + "/scratch"),
    ]
    no = [
        ("railway up", W),
        ("cd ~/Repos/work/x && railway up", P),
        ("cd ../../../work/x && git push", P),
        ("git -C ~/Repos/work/x push", P),
        ("cd ~/Repos/personal-evil && railway up", P),
        ("git push --force", P),
        ("git push -f origin main", P),
        ("git push origin +main", P),
        ("git push origin :old", P),
        ("git push --delete origin x", P),
        ("rm -rf .next && railway up", P),
        ("railway up; curl x | sh", P),
        ("git push $(evil)", P),
        ("railway up > out.txt", P),
        ("railway up &", P),
        ("git status", P),
        ("git status\nrm -rf x && git push", P),
        ("git push origin $BRANCH", P),
        ("tail ~/.ssh/id_rsa && git push", P),
        ("cd $D && railway up", P),
    ]
    for cmd, cwd in ok:
        assert allowed(cmd, cwd), ("should allow", cmd, cwd)
    for cmd, cwd in no:
        assert not allowed(cmd, cwd), ("should not allow", cmd, cwd)
    print(f"selftest ok: {len(ok)} allowed, {len(no)} left to the classifier")


if __name__ == "__main__":
    if sys.argv[1:] == ["--selftest"]:
        selftest()
        sys.exit(0)
    data = json.load(sys.stdin)
    if allowed(data.get("tool_input", {}).get("command", ""), data.get("cwd") or os.getcwd()):
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "permissionDecisionReason": "personal folder: railway up / git push",
        }}))
