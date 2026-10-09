#!/bin/zsh

# Parse arguments
CLEAN_CACHE=false
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --clean) CLEAN_CACHE=true ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

# 1. Get the absolute path of the directory where this script is located
# This ensures it works even if you run it from a different folder
DOTFILES_DIR=$(cd "$(dirname "$0")" && pwd)

echo "Setting up configs from: $DOTFILES_DIR"

# 2. Clear Neovim caches/state for a clean reinstall (only with --clean flag)
if [[ "$CLEAN_CACHE" == true ]]; then
  echo "Cleaning Neovim cache and data..."
  rm -rf ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
else
  echo "Skipping cache cleanup (use --clean to clear caches)"
fi

# 3. Create standard config directory
mkdir -p ~/.config
mkdir -p ~/.config/worktrunk

# 4. Helper function to create symlinks safely
# Usage: link_config [source_subdir] [target_path]
link_config() {
  local src="$DOTFILES_DIR/$1"
  local dest="$2"

  # Remove existing file or symlink to avoid nesting/errors
  rm -rf "$dest"

  echo "Linking $src -> $dest"
  ln -s "$src" "$dest"
}

# 5. Perform the linking
# Neovim (links the whole folder)
link_config "nvim" "$HOME/.config/nvim"

# Zsh (links the .zshrc from the root of the repo)
link_config "dotfiles/zshrc" "$HOME/.zshrc"

# Ghostty (links the whole folder)
link_config "ghostty" "$HOME/.config/ghostty"

# Zellij (links the whole folder)
link_config "zellij" "$HOME/.config/zellij"

# Starship (links the config file)
link_config "starship/starship.toml" "$HOME/.config/starship.toml"

# Worktrunk (links the global user config file)
link_config "worktrunk/config.toml" "$HOME/.config/worktrunk/config.toml"

echo "Setup complete! Restart your terminal or run 'source ~/.zshrc'"
