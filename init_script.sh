#!/bin/zsh
# Link (or render) every config in this repo into place. Safe to re-run: anything already
# at a destination that isn't our link is moved to <dest>.pre-dotfiles-<timestamp>, not deleted.

# Parse arguments
CLEAN_CACHE=false
INSTALL_BREW=false
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --clean) CLEAN_CACHE=true ;;
    --brew) INSTALL_BREW=true ;;
    *) echo "Unknown option: $1 (use --clean, --brew)"; exit 1 ;;
  esac
  shift
done

# Absolute path of this repo, so it works from any directory
DOTFILES_DIR=$(cd "$(dirname "$0")" && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)

echo "Setting up configs from: $DOTFILES_DIR"

if [[ "$INSTALL_BREW" == true ]]; then
  echo "Installing Brewfile packages..."
  brew bundle --file="$DOTFILES_DIR/Brewfile"
fi

# Clear Neovim caches/state for a clean reinstall (only with --clean flag)
if [[ "$CLEAN_CACHE" == true ]]; then
  echo "Cleaning Neovim cache and data..."
  rm -rf ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
fi

# Move whatever is at $1 out of the way
backup() {
  local dest="$1"
  if [[ -e "$dest" || -L "$dest" ]]; then
    mv "$dest" "$dest.pre-dotfiles-$STAMP"
    echo "  backed up existing $dest"
  fi
}

# Symlink a repo path into place. For files edited by hand.
# Usage: link_config <repo_path> <dest>
link_config() {
  local src="$DOTFILES_DIR/$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    return
  fi
  backup "$dest"
  echo "Linking $src -> $dest"
  ln -s "$src" "$dest"
}

# Copy a repo file into place with __HOME__ replaced by $HOME. For files that apps
# rewrite themselves (a symlink would get replaced) or that need absolute paths.
# Usage: render_config <repo_path> <dest> [--if-missing]
render_config() {
  local src="$DOTFILES_DIR/$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ "$3" == "--if-missing" && -e "$dest" ]]; then
    echo "Keeping existing $dest"
    return
  fi
  # Byte-exact (keeps a missing trailing newline), so sync.sh round-trips cleanly
  local tmp=$(mktemp)
  sed "s#__HOME__#$HOME#g" "$src" > "$tmp"
  if [[ -f "$dest" && ! -L "$dest" ]] && cmp -s "$tmp" "$dest"; then
    rm -f "$tmp"
    return
  fi
  backup "$dest"
  echo "Rendering $src -> $dest"
  mv "$tmp" "$dest"
  [[ -x "$src" ]] && chmod +x "$dest" || chmod 644 "$dest"
}

# Editors, shell, terminal
link_config "nvim" "$HOME/.config/nvim"
link_config "dotfiles/zshrc" "$HOME/.zshrc"
link_config "ghostty" "$HOME/.config/ghostty"
link_config "zellij" "$HOME/.config/zellij"
link_config "starship/starship.toml" "$HOME/.config/starship.toml"
link_config "worktrunk/config.toml" "$HOME/.config/worktrunk/config.toml"
link_config "herdr/config.toml" "$HOME/.config/herdr/config.toml"

# Claude Code
link_config "claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
link_config "claude/statusline.sh" "$HOME/.claude/statusline.sh"
link_config "claude/turn-timer.sh" "$HOME/.claude/turn-timer.sh"
link_config "claude/hooks/herdr-agent-state.sh" "$HOME/.claude/hooks/herdr-agent-state.sh"
render_config "claude/settings.json" "$HOME/.claude/settings.json"

# Codex
link_config "codex/herdr-agent-state.sh" "$HOME/.codex/herdr-agent-state.sh"
link_config "codex/rules/default.rules" "$HOME/.codex/rules/default.rules"
render_config "codex/hooks.json" "$HOME/.codex/hooks.json"
render_config "codex/config.base.toml" "$HOME/.codex/config.toml" --if-missing

# Cursor
link_config "cursor/herdr-agent-state.sh" "$HOME/.cursor/herdr-agent-state.sh"
render_config "cursor/hooks.json" "$HOME/.cursor/hooks.json"

# Statuslines
link_config "ccstatusline/settings.json" "$HOME/.config/ccstatusline/settings.json"
link_config "cxstatusline/settings.json" "$HOME/.config/cxstatusline/settings.json"
render_config "cxstatusline/turn-renderer.py" "$HOME/.config/cxstatusline/turn-renderer.py"

echo "Setup complete! Restart your terminal or run 'source ~/.zshrc'"
echo "Not covered here: herdr plugin (herdr plugin install kryptamine/herdr-auto-title),"
echo "Claude plugins (enabled in settings.json; Claude installs them on first start)."
