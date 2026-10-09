#!/bin/zsh
# Copy the rendered (non-symlinked) configs back into the repo, with $HOME turned back
# into __HOME__, so changes made by the apps themselves can be committed. Linked files
# need no syncing: editing them edits the repo.
DOTFILES_DIR=$(cd "$(dirname "$0")" && pwd)

pull() {
  local live="$1" repo="$DOTFILES_DIR/$2"
  [[ -f "$live" && ! -L "$live" ]] || return
  sed "s#$HOME#__HOME__#g" "$live" > "$repo"
}

pull "$HOME/.claude/settings.json" "claude/settings.json"
pull "$HOME/.codex/hooks.json" "codex/hooks.json"
pull "$HOME/.cursor/hooks.json" "cursor/hooks.json"
pull "$HOME/.config/cxstatusline/turn-renderer.py" "cxstatusline/turn-renderer.py"
command -v brew >/dev/null && brew bundle dump --force --no-vscode --file="$DOTFILES_DIR/Brewfile"

git -C "$DOTFILES_DIR" status --short
