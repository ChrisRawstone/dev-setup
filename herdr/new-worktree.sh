#!/usr/bin/env bash
# New wt worktree in its own Herdr workspace: Claude on the left, reviewr top right, a shell
# bottom right. Branches follow <type>/<kebab-description>, e.g. feat/multi-select-filters.
# --stack adds a column on the right: the whole stack's logs (dev-stack) above a browser on the web app.
# Bound to prefix+shift+g (and prefix+shift+f with --stack) in config.toml; runs in a popup in the
# focused pane's folder.
# Usage: new-worktree.sh [--stack] [type] [description]   (prompts for whatever is missing)
set -euo pipefail
stack=; [ "${1:-}" = --stack ] && { stack=1; shift; }

fail() { printf '\n%s\nPress any key to close.' "$1" >&2; read -rsn1 || true; exit 1; }

git rev-parse --show-toplevel >/dev/null 2>&1 || fail "Not in a git repository: $PWD"

type=${1:-$(printf '%s\n' feat fix refactor chore docs test perf ci build | fzf --height=12 --reverse --prompt='Branch type > ')} || exit 0
desc=${2:-}
[ -n "$desc" ] || read -rp "Short description (becomes $type/<kebab-case>): " desc
slug=$(printf '%s' "$desc" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')
[ -n "$slug" ] || fail "The description needs at least one letter or digit."
branch="$type/$slug"

echo "Creating worktree for $branch ..."
# Branch from the remote's default branch, since a local main is often behind.
git fetch --quiet origin || echo "Could not fetch origin; branching from the last fetched state."
base=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD || echo main)
wt switch --create "$branch" --base "$base" --no-cd || fail "wt could not create $branch."
git branch --unset-upstream "$branch" 2>/dev/null || true  # never track origin/main, so a push can't target it
path=$(git worktree list --porcelain | awk -v b="refs/heads/$branch" '/^worktree /{p=substr($0,10)} $0=="branch "b{print p}')
[ -d "$path" ] || fail "Created $branch but could not find its worktree folder."

root=$(herdr workspace create --cwd "$path" --label "$branch" --focus | jq -r .result.root_pane.pane_id)
reviewr=$(herdr plugin pane open --plugin persiyanov.reviewr --entrypoint pane --placement split \
  --target-pane "$root" --direction right --cwd "$path" --no-focus | jq -r .result.plugin_pane.pane.pane_id)
if [ -n "$stack" ]; then
  # Split the right half before it is cut horizontally, so the stack gets a full-height column.
  # Claude 30%, reviewr/terminal 30%, logs/browser 40%: the right 70% splits 0.43 / 0.57.
  logs=$(herdr pane split "$reviewr" --direction right --ratio 0.43 --cwd "$path" --no-focus | jq -r .result.pane.pane_id)
  herdr pane resize --pane "$root" --direction left --amount 0.2 >/dev/null
fi
herdr pane split "$reviewr" --direction down --cwd "$path" --no-focus >/dev/null
herdr pane run "$root" claude >/dev/null
if [ -n "$stack" ]; then
  browser=$(herdr pane split "$logs" --direction down --ratio 0.35 --cwd "$path" --no-focus | jq -r .result.pane.pane_id)
  # The labels web-preview looks for, so an agent's web-preview reuses these panes.
  herdr pane rename "$logs" "web logs" >/dev/null
  herdr pane rename "$browser" browser >/dev/null
  herdr pane run "$logs" "~/.config/herdr/dev-stack" >/dev/null
  port() { sed -nE "s/^$1=([0-9]+).*/\\1/p" "$path/.env" | tail -1; }
  url="http://localhost:$(port WEB_PORT)" api="http://127.0.0.1:$(port API_PORT)/"
  # Opens once the API answers too, so the first load doesn't show "API unreachable"; zoomed to laptop size.
  herdr pane run "$browser" "~/.config/herdr/dev-browser $url $api" >/dev/null
fi
