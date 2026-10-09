#!/bin/zsh
# Link (or render) every config in this repo into place. Safe to re-run: anything already
# at a destination that isn't our link is moved to <dest>.pre-dotfiles-<timestamp>, not deleted.

# Parse arguments
CLEAN_CACHE=false
INSTALL_BREW=false
INSTALL_EXTRAS=false
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --clean) CLEAN_CACHE=true ;;
    --brew) INSTALL_BREW=true ;;
    --extras) INSTALL_EXTRAS=true ;;
    --all) INSTALL_BREW=true; INSTALL_EXTRAS=true ;;
    *) echo "Unknown option: $1 (use --clean, --brew, --extras, --all)"; exit 1 ;;
  esac
  shift
done

# Absolute path of this repo, so it works from any directory
DOTFILES_DIR=$(cd "$(dirname "$0")" && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)

echo "Setting up configs from: $DOTFILES_DIR"

if [[ "$INSTALL_BREW" == true ]]; then
  if ! command -v brew >/dev/null && [[ ! -x /opt/homebrew/bin/brew ]]; then
    echo "Installing Homebrew (asks for an admin password / elevation)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || exit 1
  fi
  [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
  echo "Installing Brewfile packages..."
  # Keep going so configs still get linked, but report the failure at the end
  brew bundle --file="$DOTFILES_DIR/Brewfile" || BREW_FAILED=true
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

# Git and SSH (host aliases only; keys never live in this repo)
link_config "git/gitconfig" "$HOME/.gitconfig"
mkdir -p ~/.ssh && chmod 700 ~/.ssh
render_config "ssh/config" "$HOME/.ssh/config"
chmod 600 ~/.ssh/config

# Editors (macOS paths)
for editor in "vscode:Code" "cursor:Cursor"; do
  user_dir="$HOME/Library/Application Support/${editor#*:}/User"
  link_config "${editor%%:*}/User/settings.json" "$user_dir/settings.json"
  link_config "${editor%%:*}/User/keybindings.json" "$user_dir/keybindings.json"
  [[ -d "$DOTFILES_DIR/${editor%%:*}/User/snippets" ]] && link_config "${editor%%:*}/User/snippets" "$user_dir/snippets"
done

# Own skills (third-party ones are installed by --extras)
link_config "skills/web-preview" "$HOME/.agents/skills/web-preview"
link_config "skills/web-preview" "$HOME/.claude/skills/web-preview"
link_config "codex/skills/claude-skill" "$HOME/.codex/skills/claude-skill"

# ---------------------------------------------------------------------------
# --extras: things installed through each tool's own CLI. Every step is skipped
# when its tool is missing and is safe to re-run.
# ---------------------------------------------------------------------------
EXTRAS_FAILED=()
EXTRAS_LOG=$(mktemp)
extra() {  # extra <description> <command...>
  local what="$1"; shift
  echo "  $what"
  if ! "$@" </dev/null >"$EXTRAS_LOG" 2>&1; then
    echo "    FAILED: $what"; tail -8 "$EXTRAS_LOG" | sed 's/^/      /'
    EXTRAS_FAILED+=("$what")
  fi
}

if [[ "$INSTALL_EXTRAS" == true ]]; then
  echo "Installing extras..."
  [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
  export PATH="$HOME/.local/bin:$PATH"

  # Agent CLIs (official installers)
  command -v claude >/dev/null || extra "Claude Code CLI" bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
  command -v cursor-agent >/dev/null || extra "Cursor CLI" bash -c 'curl -fsS https://cursor.com/install | bash'
  # Codex CLI comes as cxstatusline's patched build + wrapper (~/.local/bin/codex)
  if command -v cxstatusline >/dev/null && ! grep -qs cxstatusline-wrapper ~/.local/bin/codex; then
    extra "Codex CLI (cxstatusline install)" cxstatusline install -y
  fi

  # Editor extensions
  for editor in "code:vscode" "cursor:cursor"; do
    cli="${editor%%:*}"
    command -v "$cli" >/dev/null || { echo "  skipping $cli extensions ($cli not installed)"; continue; }
    installed="${(L)$("$cli" --list-extensions 2>/dev/null)}"
    while read -r ext; do
      [[ -z "$ext" || "$installed" == *"${(L)ext}"* ]] && continue
      grep -qixF "$ext" "$DOTFILES_DIR/local-extensions.txt" && continue
      extra "$cli extension $ext" "$cli" --install-extension "$ext"
    done < "$DOTFILES_DIR/${editor#*:}/extensions.txt"
  done

  # Claude Code plugins: marketplaces + plugins listed in claude/settings.json
  if command -v claude >/dev/null; then
    python3 -c "
import json, sys
s = json.load(open(sys.argv[1]))
if any(p.endswith('@claude-plugins-official') for p in s.get('enabledPlugins', {})):
    print('marketplace', 'anthropics/claude-plugins-official')
if any(p.endswith('@claude-plugins-official') for p in s.get('enabledPlugins', {})):
    print('marketplace', 'anthropics/claude-plugins-official')
for m in s.get('extraKnownMarketplaces', {}).values(): print('marketplace', m['source']['repo'])
for p, on in s.get('enabledPlugins', {}).items():
    if on: print('plugin', p)" "$DOTFILES_DIR/claude/settings.json" | while read -r kind name; do
      if [[ "$kind" == marketplace ]]; then extra "Claude marketplace $name" claude plugin marketplace add "$name"
      else extra "Claude plugin $name" claude plugin install "$name"; fi
    done
  fi

  # Third-party agent skills (source + name per line)
  if command -v npx >/dev/null; then
    while read -r source skill; do
      [[ -z "$source" || -e "$HOME/.agents/skills/$skill" ]] && continue
      extra "skill $skill ($source)" npx -y skills add "$source" -g -y -s "$skill" -a '*'
    done < "$DOTFILES_DIR/skills/third-party.txt"
  fi

  # terminal-browser's own agent skills/config
  command -v terminal-browser >/dev/null && extra "terminal-browser setup" terminal-browser setup

  # herdr plugin
  if command -v herdr >/dev/null && ! herdr plugin list 2>/dev/null | grep -q auto-title; then
    extra "herdr Auto Title plugin" herdr plugin install kryptamine/herdr-auto-title
  fi

  # Azure CLI extensions
  if command -v az >/dev/null; then
    have="$(az extension list --query '[].name' -o tsv 2>/dev/null)"
    while read -r ext; do
      [[ -z "$ext" || "$have" == *"$ext"* ]] && continue
      extra "az extension $ext" az extension add --name "$ext" --yes
    done < "$DOTFILES_DIR/azure-cli-extensions.txt"
  fi
fi

if [[ "$BREW_FAILED" == true || ${#EXTRAS_FAILED[@]} -gt 0 ]]; then
  echo "Configs linked, but some installs FAILED:"
  [[ "$BREW_FAILED" == true ]] && echo "  - Brewfile packages (see 'has failed!' above)"
  for f in "${EXTRAS_FAILED[@]}"; do echo "  - $f"; done
  echo "Fix those and re-run; everything else is skipped when already done."
  exit 1
fi
echo "Setup complete! Restart your terminal or run 'source ~/.zshrc'"
[[ "$INSTALL_EXTRAS" != true ]] && echo "Run with --extras to install editor extensions, agent CLIs, plugins and skills."
