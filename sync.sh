#!/bin/zsh
# Copy the rendered (non-symlinked) configs back into the repo, with $HOME turned back
# into __HOME__, so changes made by the apps themselves can be committed. Linked files
# need no syncing: editing them edits the repo.
# Pass --brew to also re-dump the Brewfile from what this machine has installed.
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
pull "$HOME/.ssh/config" "ssh/config"

# Installed-things lists (only when the tool exists, so a bare machine doesn't wipe them)
command -v cursor >/dev/null && cursor --list-extensions | sort -f > "$DOTFILES_DIR/cursor/extensions.txt"
command -v code >/dev/null && code --list-extensions | sort -f > "$DOTFILES_DIR/vscode/extensions.txt"
command -v az >/dev/null && az extension list --query '[].name' -o tsv | sort > "$DOTFILES_DIR/azure-cli-extensions.txt"
[[ "$1" == "--brew" ]] && brew bundle dump --force --no-vscode --file="$DOTFILES_DIR/Brewfile"

git -C "$DOTFILES_DIR" status --short
