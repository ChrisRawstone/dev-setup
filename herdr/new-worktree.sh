#!/usr/bin/env bash
# New wt worktree in its own Herdr workspace: Claude on the left, its changes (reviewr, or herdr-app's
# Changes pane) on the right. Branches follow <type>/<kebab-description>, e.g. feat/multi-select-filters.
# --stack also runs the whole stack (dev-stack) in a paneless hc terminal `stack-<branch>` (see it with
# `hc attach stack-…`, or peek it in herdr-app's agents list) and puts a browser on the web app above
# the changes, kept sized for a 16:10 page on whatever screen it's on by a background fit-stack.
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

if [ -n "$stack" ]; then
  port() { sed -nE "s/^$1=([0-9]+).*/\\1/p" "$path/.env" | tail -1; }
  url="http://localhost:$(port WEB_PORT)" api="http://127.0.0.1:$(port API_PORT)/"
fi
stack_name=$(printf 'stack-%s-%s' "$type" "$slug" | cut -c1-32)  # hc names: at most 32 characters
# dev-stack in zsh -lic for ~/.zshrc's PATH (bun); `wt remove --reap` stops it with the worktree.
run_stack() { hc run --bg --no-notify --name "$stack_name" --cwd "$path" "$@" -- \
  /bin/zsh -lic 'exec "$@"' zsh "$HOME/.config/herdr/dev-stack" >/dev/null; }
fit_stack="$HOME/.config/herdr/fit-stack"
# fit-stack keeps running after this popup closes, in an hc terminal (a nohup'd job dies with the
# popup's): `fit_in_background <hc run options> -- <fit-stack args>`. It ends with its space.
fit_in_background() {
  local opts=()
  while [ "$1" != -- ]; do opts+=("$1"); shift; done; shift
  hc run --bg --no-notify --name "$(printf 'fit-%s-%s' "$type" "$slug" | cut -c1-32)" "${opts[@]}" -- env \
    ${HERDR_SESSION:+HERDR_SESSION="$HERDR_SESSION"} ${HERDR_SOCKET_PATH:+HERDR_SOCKET_PATH="$HERDR_SOCKET_PATH"} \
    "$fit_stack" "$@" >/dev/null
}

if [ -n "${HC_TERMINAL_ID:-}" ]; then
  # herdr-app (mods/popup-new-*). Its splits are halves; fit-stack then sets the sizes.
  pane_of() { herdr-app ls | jq -r --arg t "$1" '.spaces[].tabs[].terminals[] | select(.terminal == $t) | .pane'; }
  split() { herdr-app do pane.split --pane "$@" | jq -r .pane; }
  # pane.split runs argv bare (space.new wraps it), so run it like herdr-app's tabs: in zsh -lic.
  in_shell() { jq -cn --args '["/bin/zsh", "-lic", "\"$@\"; exec \"$0\" -li", "/bin/zsh"] + $ARGS.positional' "$@"; }
  claude=$(herdr-app do space.new --name "$branch" --folder "$path" --argv '["claude"]' | jq -r .terminal)
  root=$(pane_of "$claude")
  if [ -n "$stack" ]; then
    run_stack --parent "$claude"  # a child of Claude's terminal: no pane, and it ends with the space
    b=$(herdr-app do pane.split --pane "$root" --direction right \
      --argv "$(in_shell "$HOME/.config/herdr/dev-browser" "$url" "$api")")
    browser=$(jq -r .pane <<<"$b")
    changes=$(split "$browser" --direction down --mod changes)
    fit_in_background --parent "$claude" -- app "$claude" "$(jq -r .terminal <<<"$b")" "$root" "$browser" "$changes"
  else
    changes=$(split "$root" --direction right --mod changes)
    "$fit_stack" weights "$root" 0.6 "$changes" 0.4 || true
  fi
  herdr-app do pane.focus --pane "$root" >/dev/null
  exit 0
fi

# Old Herdr.
root=$(herdr workspace create --cwd "$path" --label "$branch" --focus | jq -r .result.root_pane.pane_id)
if [ -n "$stack" ]; then
  run_stack --no-parent
  browser=$(herdr pane split "$root" --direction right --cwd "$path" --no-focus | jq -r .result.pane.pane_id)
  herdr plugin pane open --plugin persiyanov.reviewr --entrypoint pane --placement split \
    --target-pane "$browser" --direction down --cwd "$path" --no-focus >/dev/null
  fit_in_background --no-parent -- old "$root" "$browser"
  herdr pane rename "$browser" browser >/dev/null  # the label web-preview looks for, so it reuses this pane
  # Opens once the API answers too, so the first load doesn't show "API unreachable".
  herdr pane run "$browser" "~/.config/herdr/dev-browser $url $api" >/dev/null
else
  herdr plugin pane open --plugin persiyanov.reviewr --entrypoint pane --placement split \
    --target-pane "$root" --direction right --cwd "$path" --no-focus >/dev/null
fi
herdr pane run "$root" claude >/dev/null
