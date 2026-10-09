# dev-setup

Christian's macOS developer setup: dotfiles, apps, CLIs, editor extensions, agent
(Claude / Codex / Cursor) configs and plugins. One script puts a fresh Mac back the
way it was, and tells you at the end what worked, what didn't, and how to fix it.

## New Mac: step by step

Do these in order; each step unblocks the next. Written for the Accenture Jamf → Intune
migration (full wipe), but works for any fresh Mac.

> **Never let a script or AI move files into or out of OneDrive.** Accenture's malware
> protection flags it and can cut your internet. Scripts here only touch local folders;
> every OneDrive copy below is a drag in Finder.

### Before the wipe (old Mac)

1. **Push your git work.** Only pushed commits come back. Check every repo for unpushed
   commits, stashes and uncommitted changes, including worktrees.
2. **Run the backup:** `bash ~/scratch/mac-migration/backup.sh`. It writes
   `~/MacMigration-<date>/` locally: personal files, tokens, Claude/Codex/Cursor history,
   `.env` files, app lists. Then **drag that folder into OneDrive in Finder.**
3. **Downloads and other local files** aren't in OneDrive's automatic backup (only Desktop
   and Documents are). Drag what you need into OneDrive, e.g. a `Downloads Backup` folder.
4. **Secrets into 1Password** (IT's recommendation): SSH keys (`~/.ssh/id_*`), tokens and
   `.env` files. The backup has them too, but 1Password is the safer copy.
5. **1Password Emergency Kit** (Secret Key) saved, or 1Password logged in on your phone.
   The account password alone isn't enough on a new Mac.
6. **Browsers:** turn on sync (Chrome, Firefox) or export bookmarks; passwords into 1Password.
7. **Apple Notes:** notes under *On My Mac* aren't synced anywhere. Move them to iCloud or export them.
8. **Wait until OneDrive says *Your files are synced*,** then spot-check on onedrive.com.
9. **Sign out of iCloud** (System Settings → your name → Sign Out). Otherwise the Mac is
   locked (Activation Lock) after the wipe.

### Migration day

1. **Be at home**: Accenture Wi-Fi only works after the initial setup.
2. Run **Intune Migration** in *My Accenture Mac*. Not there? Email va.support@accenture.com
   ("I can't see the Intune Migration icon"), or contact Jens Nielsen.
3. After the wipe choose **Reinstall macOS Tahoe** if offered. Stuck on *Choose Startup
   Disk*? Recovery mode helps.
4. Set up with your **Enterprise ID** (xyz@accenture.com), enroll in Intune and register PSSO,
   all in the same session. Then wait for the mandatory downloads (Office, Teams, Defender...).

### On the new Mac

1. **Company Portal:** sign in. Install OneDrive from there if it isn't on the Mac yet.
2. **OneDrive:** sign in, then **in Finder** drag `MacMigration-<date>` from OneDrive to your
   home folder, plus anything else you parked there (Downloads Backup...).
3. **App Store:** sign in, so Xcode and 1Password for Safari can install.
4. **Command line tools** (gives you `git`). In Terminal: `xcode-select --install`
5. **Restore personal files** (SSH keys, tokens, Claude/Codex history, work git email):
   ```bash
   B=$(ls -d ~/MacMigration-* | tail -1)
   tar -xzf "$B/configs/home-configs.tar.gz" -C ~
   chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_* ~/.ssh/config
   ssh -T git@github-chrisrawstone        # should say: Hi ChrisRawstone!
   ```
6. **Get this repo** (public, so no keys or login needed):
   ```bash
   git clone https://github.com/ChrisRawstone/dev-setup.git ~/Repos/dev-setup
   git -C ~/Repos/dev-setup remote set-url --push origin git@github-chrisrawstone:ChrisRawstone/dev-setup.git
   ```
   (The second line makes pushes use your SSH key.) No network? Use the backup copy: `cp -R "$B/dev-setup" ~/Repos/dev-setup`
7. **Get admin, then run everything.** Company Portal → *Promote user to Admin for 10 minutes*,
   then straight away:
   ```bash
   ~/Repos/dev-setup/init_script.sh --all
   ```
   Homebrew's installer needs admin at the start; the rest doesn't. If you aren't admin
   when the apps install, they go to `~/Applications` (they work the same, and update
   themselves without elevation prompts). Takes 20–40 minutes.
8. **Read the recap at the end.** Every failure has a suggested fix. Fix it, then run the same
   command again: finished steps are skipped. Full output: `~/.local/state/dev-setup/init-<time>.log`.
9. **When Xcode has finished downloading** (~10 GB): get admin again, then
   `~/Repos/dev-setup/init_script.sh --extras`. It selects Xcode and builds Macchiato.
10. **Open a new Ghostty window** and do the sign-ins the recap lists (Claude Code, Cursor,
    ChatGPT, 1Password, Chrome/Firefox sync, Notion, `gh auth login`, `az login`). Sign in to
    iCloud again if you use it.
11. **Your other repos and their `.env` files:** ask Claude Code to follow `RESTORE.md` (Phase 3)
    in `~/MacMigration-<date>`.

## What the script does

| Flag | What it does |
|------|--------------|
| *(none)* | Links/renders every config below. Fast, safe on an already-set-up Mac. |
| `--brew` | Installs Homebrew if missing, then everything in `Brewfile`: CLI tools, apps (Ghostty, Cursor, VS Code, Claude, ChatGPT, Chrome, Firefox, 1Password, Notion, Spotify, WhatsApp, LibreOffice, Podman Desktop, ...) and App Store apps (Xcode, 1Password for Safari). |
| `--extras` | Claude Code + Cursor CLIs, Codex (cxstatusline build + turn timer), VS Code + Cursor extensions, Claude plugins, agent skills, terminal-browser setup, herdr plugin, Azure CLI extensions, and builds your own apps: Macchiato and the AgentsCompare extension. |
| `--all` | `--brew` + `--extras` |
| `--clean` | Also clears Neovim caches. |

**Fallbacks built in**

- Already-installed apps (from Company Portal, the App Store or a manual download) are detected and skipped instead of breaking the Homebrew run.
- Private repos (Macchiato, AgentsCompare) clone over SSH, and fall back to the GitHub CLI (`gh auth login`) if SSH isn't set up yet.
- A failing step never stops the rest: everything else still installs, and the recap lists what failed.
- Existing files are never deleted: anything replaced is moved to `<file>.pre-dotfiles-<time>`. If an app had changed one of its config files, the recap tells you and how to keep those changes.
- Before installing, a preflight warns about the usual blockers (no network, no command line tools, SSH keys not restored).

**Troubleshooting**

| Symptom | Fix |
|---------|-----|
| Homebrew: "Need sudo access" / admin prompt | Company Portal → *Promote user to Admin for 10 minutes*, then re-run. |
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
