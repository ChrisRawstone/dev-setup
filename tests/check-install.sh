#!/bin/bash
# Install this repo's configs into the current $HOME and check the result.
# Works on macOS and Linux. Meant for a throwaway machine (CI runner, container):
# it overwrites ~/.zshrc and ~/.claude/settings.json with dummies first, to test backups.
#   tests/check-install.sh            use the repo this script lives in
#   tests/check-install.sh <git-url>  clone it to ~/dev-setup first
set -u
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; FAILED=1; }
FAILED=0
LOGS=$(mktemp -d)

if [[ $# -gt 0 ]]; then
  git clone -q "$1" ~/dev-setup || { echo "clone failed"; exit 1; }
  REPO=~/dev-setup
else
  REPO=$(cd "$(dirname "$0")/.." && pwd)
fi

# Pre-existing files a fresh Mac might already have
mkdir -p ~/.claude
echo '{"old":true}' > ~/.claude/settings.json
echo "# old zshrc" > ~/.zshrc

echo "== run 1"
zsh "$REPO/init_script.sh" > "$LOGS/run1.log" 2>&1 || fail "init_script.sh exited non-zero"
if grep -qiE 'error|No such file|permission denied' "$LOGS/run1.log"; then
  fail "errors in run 1:"; grep -iE 'error|No such file|permission denied' "$LOGS/run1.log"
fi
grep -qs old ~/.claude/settings.json.pre-dotfiles-* && pass "existing settings.json backed up" || fail "settings.json not backed up"
ls ~/.zshrc.pre-dotfiles-* >/dev/null 2>&1 && pass "existing .zshrc backed up" || fail ".zshrc not backed up"

links=$(grep -c '^Linking' "$LOGS/run1.log")
renders=$(grep -c '^Rendering' "$LOGS/run1.log")
broken=$(grep '^Linking' "$LOGS/run1.log" | sed 's/.* -> //' | while read -r d; do [[ -e "$d" ]] || echo "$d"; done)
[[ -z "$broken" ]] && pass "$links symlinks created, none broken" || fail "broken links: $broken"
[[ $renders -eq 5 ]] && pass "5 files rendered" || fail "rendered $renders files (expected 5)"

for f in ~/.claude/settings.json ~/.codex/hooks.json ~/.cursor/hooks.json ~/.config/cxstatusline/turn-renderer.py ~/.codex/config.toml; do
  grep -q '__HOME__' "$f" && fail "unrendered __HOME__ in $f"
done
grep -q "$HOME/.claude/turn-timer.sh" ~/.claude/settings.json && pass "rendered paths use $HOME" || fail "settings.json paths wrong"
python3 -c "import json,os;[json.load(open(os.path.expanduser(f))) for f in ['~/.claude/settings.json','~/.codex/hooks.json','~/.cursor/hooks.json']]" \
  && pass "rendered JSON valid" || fail "rendered JSON invalid"

echo "== run 2 (idempotence)"
zsh "$REPO/init_script.sh" > "$LOGS/run2.log" 2>&1
if grep -qE '^(Linking|Rendering)|backed up' "$LOGS/run2.log"; then
  fail "second run changed things:"; grep -E '^(Linking|Rendering)|backed up' "$LOGS/run2.log"
else
  pass "second run is a no-op"
fi

echo "== sync round-trip"
zsh "$REPO/sync.sh" > /dev/null 2>&1
diff=$(git -C "$REPO" status --short)
[[ -z "$diff" ]] && pass "sync.sh round-trips with no diff" || fail "sync.sh produced diff: $diff"

echo "== shell + scripts"
zsh -i -c 'echo ZSH_OK' > "$LOGS/zsh.out" 2> "$LOGS/zsh.err"
grep -q ZSH_OK "$LOGS/zsh.out" && pass "interactive zsh starts" || fail "zsh did not start"
if [[ -s "$LOGS/zsh.err" ]]; then
  fail "zsh startup printed errors:"; head -20 "$LOGS/zsh.err" | sed 's/^/    /'
fi
status_json='{"model":{"display_name":"Opus"},"workspace":{"current_dir":"'$HOME'"},"context_window":{"current_usage":{"input_tokens":1200},"context_window_size":200000},"cost":{"total_cost_usd":0.12}}'
out=$(echo "$status_json" | ~/.claude/statusline.sh 2>&1); rc=$?
if [[ $rc -eq 0 && -n "$out" ]]; then
  pass "Claude statusline renders: $(echo "$out" | sed $'s/\x1b\\[[0-9;]*m//g' | head -1 | cut -c1-90)"
else
  fail "statusline rc=$rc: $out"
fi
echo '{"session_id":"t1"}' | ~/.claude/turn-timer.sh start && echo '{"session_id":"t1"}' | ~/.claude/turn-timer.sh stop \
  && pass "turn-timer start/stop" || fail "turn-timer"

echo
if [[ $FAILED -eq 0 ]]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; fi
exit $FAILED
