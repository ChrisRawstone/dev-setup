# dev-setup

Christian's macOS developer setup: dotfiles, apps, CLIs, editor extensions, agent
(Claude / Codex / Cursor) configs and plugins. One script puts a fresh Mac back the
way it was, and tells you at the end what worked, what didn't, and how to fix it.

## New Mac: step by step

Do these in order; each step unblocks the next.

**Before wiping the old Mac**

1. Run the backup: `bash ~/scratch/mac-migration/backup.sh` (writes `~/Desktop/MacMigration-<date>/`).
2. Wait until OneDrive says *Up to date*, and spot-check the folder on onedrive.com.
3. Push any git work you want to keep (only pushed commits come back).
4. Have your 1Password Secret Key (Emergency Kit), or your phone with 1Password on it.

**On the new Mac**

1. **Accenture setup.** Sign in with SSO, finish Company Portal enrollment, and install
   Office, Teams, Edge etc. from Self Service. (This repo doesn't install managed apps.)
2. **OneDrive.** Sign in and let `Desktop/MacMigration-<date>` sync down.
3. **App Store.** Open it and sign in, so Xcode and 1Password for Safari can install later.
4. **Command line tools** (gives you `git`). In Terminal: `xcode-select --install`
5. **Restore personal files from the backup** (SSH keys, tokens, Claude/Codex history, work git email):
   ```bash
   B=$(ls -d ~/Desktop/MacMigration-* | tail -1)
   tar -xzf "$B/configs/home-configs.tar.gz" -C ~
   chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_* ~/.ssh/config
   ssh -T git@github-chrisrawstone        # should say: Hi ChrisRawstone!
   ```
6. **Get this repo.**
   ```bash
   git clone git@github-chrisrawstone:ChrisRawstone/dev-setup.git ~/Repos/dev-setup
   ```
   SSH not working? Use the copy in the backup instead: `cp -R "$B/dev-setup" ~/Repos/dev-setup`
7. **Run everything** (20–40 min; approve the admin/elevation prompt for Homebrew):
   ```bash
   ~/Repos/dev-setup/init_script.sh --all
   ```
8. **Read the recap at the end.** Every failure comes with a suggested fix. Fix, then run the
   same command again: finished steps are skipped, so re-running is cheap. The full output is
   saved to `~/.local/state/dev-setup/init-<time>.log`.
9. **When Xcode has finished downloading** (it's ~10 GB), run `~/Repos/dev-setup/init_script.sh --extras`
   once more: it selects Xcode (admin prompt) and builds Macchiato.
10. **Open a new Ghostty window** and do the sign-ins the recap lists (Claude Code, Cursor,
    ChatGPT, 1Password, Chrome sync, Notion, `gh auth login`, `az login`).
11. **Your other repos and their `.env` files:** ask Claude Code to follow `RESTORE.md` (Phase 3)
    in the backup folder.

## What the script does

| Flag | What it does |
|------|--------------|
| *(none)* | Links/renders every config below. Fast, safe on an already-set-up Mac. |
| `--brew` | Installs Homebrew if missing, then everything in `Brewfile`: CLI tools, apps (Ghostty, Cursor, VS Code, Claude, ChatGPT, Chrome, Firefox, 1Password, Notion, Spotify, WhatsApp, LibreOffice, Podman Desktop, ...) and App Store apps (Xcode, 1Password for Safari). |
| `--extras` | Claude Code + Cursor CLIs, Codex (cxstatusline build + turn timer), VS Code + Cursor extensions, Claude plugins, agent skills, terminal-browser setup, herdr plugin, Azure CLI extensions, and builds your own apps: Macchiato and the AgentsCompare extension. |
| `--all` | `--brew` + `--extras` |
| `--clean` | Also clears Neovim caches. |

**Fallbacks built in**

- Already-installed apps (from Self Service, the App Store or a manual download) are detected and skipped instead of breaking the Homebrew run.
- Private repos (Macchiato, AgentsCompare) clone over SSH, and fall back to the GitHub CLI (`gh auth login`) if SSH isn't set up yet.
- A failing step never stops the rest: everything else still installs, and the recap lists what failed.
- Existing files are never deleted: anything replaced is moved to `<file>.pre-dotfiles-<time>`. If an app had changed one of its config files, the recap tells you and how to keep those changes.
- Before installing, a preflight warns about the usual blockers (no network, no command line tools, SSH keys not restored).

**Troubleshooting**

| Symptom | Fix |
|---------|-----|
| Homebrew install stops at an admin prompt | Approve it in PrivilegeManagement (Accenture EPM), re-run. |
| `clone ChrisRawstone/...` failed | Step 5 not done (SSH keys), or run `gh auth login`; re-run `--extras`. |
| Xcode / 1Password for Safari not installed | Sign in to the App Store, re-run `--brew`. |
| Macchiato "needs Xcode" | Wait for Xcode, re-run `--extras`. Quick fallback: unzip `macchiato/Macchiato.app.zip` from the backup, then `xattr -dr com.apple.quarantine /Applications/Macchiato.app`. |
| A cask says "already an App at ..." | Delete or move the old app, or just leave it: it's skipped next run. |
| `zsh` errors in a new terminal | `./init_script.sh --brew` first (zshrc expects Homebrew tools), then open a new window. |
| Codex statusline lost its turn timer after `cxstatusline upgrade` | Re-run `--extras`. |

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
| `git/gitconfig`, `git/gitconfig-personal` | `~/.gitconfig`, `~/.gitconfig.personal` (work email stays in untracked `~/.gitconfig.local`; repos on the ChrisRawstone account use the GitHub noreply address) |
| `vscode/User/`, `cursor/User/` settings + keybindings | `~/Library/Application Support/{Code,Cursor}/User/` |
| `skills/web-preview`, `codex/skills/claude-skill` | `~/.agents/skills/`, `~/.claude/skills/`, `~/.codex/skills/` |

**Rendered** (copied with `__HOME__` replaced by your home path; the apps rewrite these
themselves, so run `./sync.sh` to pull their changes back into the repo before committing):

| Source | Destination |
|--------|-------------|
| `claude/settings.json` | `~/.claude/settings.json` |
| `codex/hooks.json` | `~/.codex/hooks.json` |
| `codex/config.base.toml` | `~/.codex/config.toml` (only if it doesn't exist yet) |
| `cursor/hooks.json` | `~/.cursor/hooks.json` |
| `cxstatusline/turn-renderer.py` | `~/.config/cxstatusline/turn-renderer.py` |
| `ssh/config` (host aliases only, never keys) | `~/.ssh/config` |

Anything already at a destination is moved to `<dest>.pre-dotfiles-<timestamp>`, never deleted.

## Day to day

```bash
# Changed a linked file (zshrc, CLAUDE.md, editor settings...)? It's already in the repo:
git -C ~/Repos/dev-setup status

# An app changed one of its own config files (Claude settings, hooks...)? Pull it in:
./sync.sh

# Installed new tools/apps/extensions and want them on the next Mac too?
./sync.sh --installed   # re-dumps Brewfile + extension lists; review the diff (Brewfile loses comments)

# Then commit and push. CI checks every push: secret scan + install test on Linux,
# and a full fresh-Mac install when the Brewfile or scripts change.
```

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
