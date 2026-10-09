# Dotfiles

Personal configuration files for macOS development environment.

## What's Included

- **Neovim** - LazyVim-based configuration
- **Ghostty** - Terminal emulator config (Tokyo Night theme)
- **Zellij** - Terminal multiplexer with custom layouts
- **Zsh** - Shell configuration with plugins
- **Starship** - Cross-shell prompt (Tokyo Night preset)
- **Worktrunk** - Git worktree defaults

## Prerequisites

### Required

```bash
# Install Homebrew first if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required dependencies
brew install --cask ghostty font-jetbrains-mono-nerd-font
brew install neovim zellij tmux starship zsh-autosuggestions zsh-syntax-highlighting fd fzf
```

### Optional

For specific development workflows:

```bash
brew install go nvm postgresql@17 openjdk@21 terraform
```

## Installation

```bash
# Clone the repo
git clone git@github.com:ChrisRawstone/dev-setup.git ~/Repos/dev-setup

# Run the init script
cd ~/Repos/dev-setup
./init_script.sh

# Restart your terminal
```

## What goes where

**Linked** (editing the live file edits the repo):

| Source | Destination |
|--------|-------------|
| `nvim/` | `~/.config/nvim` |
| `ghostty/` | `~/.config/ghostty` |
| `zellij/` | `~/.config/zellij` |
| `dotfiles/zshrc` | `~/.zshrc` |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `worktrunk/config.toml` | `~/.config/worktrunk/config.toml` |
| `herdr/config.toml` | `~/.config/herdr/config.toml` |
| `claude/CLAUDE.md`, `statusline.sh`, `turn-timer.sh`, `hooks/` | `~/.claude/` |
| `codex/herdr-agent-state.sh`, `rules/default.rules` | `~/.codex/` |
| `cursor/herdr-agent-state.sh` | `~/.cursor/` |
| `ccstatusline/settings.json`, `cxstatusline/settings.json` | `~/.config/ccstatusline/`, `~/.config/cxstatusline/` |

**Rendered** (copied with `__HOME__` replaced by your home path; the apps rewrite these
themselves, so run `./sync.sh` to pull their changes back into the repo before committing):

| Source | Destination |
|--------|-------------|
| `claude/settings.json` | `~/.claude/settings.json` |
| `codex/hooks.json` | `~/.codex/hooks.json` |
| `codex/config.base.toml` | `~/.codex/config.toml` (only if it doesn't exist yet) |
| `cursor/hooks.json` | `~/.cursor/hooks.json` |
| `cxstatusline/turn-renderer.py` | `~/.config/cxstatusline/turn-renderer.py` |

Anything already at a destination is moved to `<dest>.pre-dotfiles-<timestamp>`, never deleted.

## Usage

### Init Script

```bash
# Standard setup (links + renders configs)
./init_script.sh

# Also install everything in the Brewfile
./init_script.sh --brew

# Clean setup (also clears Neovim caches)
./init_script.sh --clean

# Pull app-made changes (Claude settings, hooks, Brewfile) back into the repo
./sync.sh
```

Not automated: the herdr Auto Title plugin (`herdr plugin install kryptamine/herdr-auto-title`).
Claude plugins are listed in `claude/settings.json` and get installed on first start.

### Zellij Sessions

The `dev` layout has three tabs: **Neovim**, **Agent** (two stacked shells for Cursor `agent`), and **Terminal**.

```bash
# Start or attach a Zellij session for current or specified directory
workon [folder]

# Always start a fresh session (never attach)
workon --fresh [folder]

# Prepare issue worktree and start/attach dev session (Agent tab: two terminals; run `agent` manually)
workon-issue [issue-number]

# Same as above, but always start fresh session
workon-issue --fresh [issue-number]

# Worktrees are stored under ~/source/.worktrees/<owner-repo>/
# Override with WORKTREE_BASE=/custom/path

# Worktrunk global defaults (via ~/.config/worktrunk/config.toml)
# New wt worktrees are stored under ~/source/.worktrees/<repo>/<branch>/
# .env, backend/.env, and frontend/.env are copied if present

# Start with fullstack layout (multiple panes)
workon-fullstack [folder]
```
