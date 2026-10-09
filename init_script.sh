#!/bin/zsh
# Set up this Mac from the repo: link/render configs, and optionally install Homebrew +
# Brewfile (--brew) and tool-specific extras (--extras). Safe to re-run: finished steps
# are skipped, and anything a link would replace is moved to <dest>.pre-dotfiles-<timestamp>.
# Ends with a recap of what was installed, skipped and failed, with a suggested fix for each.

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

# Everything printed also goes to a log file, named in the recap
LOG_DIR="$HOME/.local/state/dev-setup"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/init-$STAMP.log"
exec > >(tee -a "$LOG") 2>&1

# ---------------------------------------------------------------------------
# Bookkeeping for the recap
# ---------------------------------------------------------------------------
DONE=()      # installed / set up this run
SKIPPED=()   # already there
FAILED=()    # "what<TAB>suggested fix"
TODO=()      # things only you can do
LINKED=0; RENDERED=0; MOVED_ASIDE=0

ok()     { DONE+=("$1"); }
skipped(){ SKIPPED+=("$1"); }
failed() { FAILED+=("$1"$'\t'"$2"); echo "    FAILED: $1"; }
todo()   { TODO+=("$1"); }

STEP_LOG=$(mktemp)
# extra <what> <suggested fix> <command...>: run one install step quietly; on failure
# show the end of its output and record it for the recap.
extra() {
  local what="$1" fix="$2"; shift 2
  echo "  $what"
  if "$@" </dev/null >"$STEP_LOG" 2>&1; then
    ok "$what"
  else
    tail -8 "$STEP_LOG" | sed 's/^/      /'
    failed "$what" "$fix"
    return 1
  fi
}

# clone_repo <dest> <ssh-url> <owner/repo> [override-url]: SSH first, then the GitHub CLI
clone_repo() {
  local dest="$1" url="$2" slug="$3" override="$4"
  [[ -d "$dest/.git" ]] && return 0
  if [[ -n "$override" ]]; then
    extra "clone $slug" "git clone $override $dest" git clone "$override" "$dest"; return
  fi
  echo "  clone $slug"
  if GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10" git clone -q "$url" "$dest" >"$STEP_LOG" 2>&1; then
    ok "clone $slug (SSH)"
  elif command -v gh >/dev/null && gh auth status &>/dev/null && gh repo clone "$slug" "$dest" >"$STEP_LOG" 2>&1; then
    ok "clone $slug (GitHub CLI fallback; SSH didn't work)"
  else
    tail -4 "$STEP_LOG" | sed 's/^/      /'
    failed "clone $slug" "Restore ~/.ssh from the backup (then: chmod 600 ~/.ssh/id_*) and check 'ssh -T git@github-chrisrawstone', or run 'gh auth login'; then re-run --extras"
    return 1
  fi
}

echo "Setting up configs from: $DOTFILES_DIR"
echo "Log: $LOG"

# ---------------------------------------------------------------------------
# Preflight: catch the usual blockers before spending time installing
# ---------------------------------------------------------------------------
if [[ "$INSTALL_BREW" == true || "$INSTALL_EXTRAS" == true ]]; then
  echo "Preflight..."
  [[ "$(uname -s)" == Darwin ]] || echo "  WARNING: not macOS; Homebrew casks and app steps won't work here"
  curl -fsS --max-time 10 -o /dev/null https://github.com \
    || echo "  WARNING: can't reach github.com; installs will fail until the network works"
  xcode-select -p &>/dev/null \
    || echo "  WARNING: Xcode Command Line Tools missing; run 'xcode-select --install' first"
  if [[ "$INSTALL_EXTRAS" == true && ! -f ~/.ssh/id_ed25519_chrisrawstone ]]; then
    echo "  WARNING: personal SSH key (~/.ssh/id_ed25519_chrisrawstone) not found; private repos"
    echo "           (Macchiato, AgentsCompare) will try the GitHub CLI instead. Restore ~/.ssh from the backup."
  fi
fi

# ---------------------------------------------------------------------------
# --brew: Homebrew + Brewfile
# ---------------------------------------------------------------------------
if [[ "$INSTALL_BREW" == true ]]; then
  if ! command -v brew >/dev/null && [[ ! -x /opt/homebrew/bin/brew ]]; then
    echo "Installing Homebrew (asks for an admin password / elevation)..."
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
      ok "Homebrew"
    else
      failed "Homebrew" "Approve the admin/elevation prompt (Accenture EPM), then re-run with --brew"
    fi
  fi
  [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"

  if command -v brew >/dev/null; then
    # Apps already installed outside Homebrew (Self Service, App Store, a manual
    # download) make `brew install --cask` fail with "already an App at ...": skip them.
    cask_skip=()
    for cask in $(awk -F'"' '/^cask /{print $2}' "$DOTFILES_DIR/Brewfile"); do
      brew list --cask "$cask" &>/dev/null && continue
      for app in ${(f)"$(brew info --cask --json=v2 "$cask" 2>/dev/null | python3 -c '
import json, sys
for c in json.load(sys.stdin)["casks"]:
    for a in c.get("artifacts", []):
        if isinstance(a, dict) and "app" in a:
            print(a["app"][0] if isinstance(a["app"][0], str) else a["app"][0].get("target", ""))')"}; do
        if [[ -n "$app" && ( -e "/Applications/$app" || -e "$HOME/Applications/$app" ) ]]; then
          echo "  $app is already installed (not via Homebrew), skipping cask $cask"
          skipped "$app (installed outside Homebrew)"
          cask_skip+=("$cask")
        fi
      done
    done

    echo "Installing Brewfile packages..."
    HOMEBREW_BUNDLE_CASK_SKIP="${cask_skip[*]} ${HOMEBREW_BUNDLE_CASK_SKIP:-}" \
      brew bundle --file="$DOTFILES_DIR/Brewfile"

    # Recap per entry: whatever `brew bundle check` still reports missing
    missing=$(brew bundle check --file="$DOTFILES_DIR/Brewfile" --verbose 2>/dev/null \
      | sed -n 's/^→ \(.*\) needs to be installed or updated\.$/\1/p')
    total=$(grep -cE '^(brew|cask|mas|npm|uv) ' "$DOTFILES_DIR/Brewfile")
    n_missing=0
    while IFS= read -r entry; do
      [[ -z "$entry" ]] && continue
      kind="${entry% *}"; name="${entry##* }"
      case "$kind" in
        Cask) (( ${cask_skip[(Ie)$name]} )) && continue
              failed "Brewfile cask $name" "brew install --cask $name (the log above shows why it failed)" ;;
        Formula) failed "Brewfile formula $name" "brew install $name" ;;
        *App\ Store*|*Mas*|*mas*)
              todo "Sign in to the App Store app, then re-run './init_script.sh --brew' for: $name" ;;
        *)    failed "Brewfile $entry" "brew bundle --file=$DOTFILES_DIR/Brewfile, and read its output" ;;
      esac
      (( n_missing++ ))
    done <<< "$missing"
    ok "Brewfile: $(( total - n_missing - ${#cask_skip[@]} )) of $total entries installed or up to date"
  fi
fi

# Clear Neovim caches/state for a clean reinstall (only with --clean flag)
if [[ "$CLEAN_CACHE" == true ]]; then
  echo "Cleaning Neovim cache and data..."
  rm -rf ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
fi

# ---------------------------------------------------------------------------
# Configs (always)
# ---------------------------------------------------------------------------
# Move whatever is at $1 out of the way
backup() {
  local dest="$1"
  if [[ -e "$dest" || -L "$dest" ]]; then
    mv "$dest" "$dest.pre-dotfiles-$STAMP"
    echo "  moved existing $dest aside"
    (( MOVED_ASIDE++ ))
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
  ln -s "$src" "$dest" && (( LINKED++ ))
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
  if [[ -f "$dest" && ! -L "$dest" ]]; then
    todo "${dest/#$HOME/~} had changes not in the repo (probably made by the app). The repo version was applied;
      yours is saved as ${dest/#$HOME/~}.pre-dotfiles-$STAMP. To keep them: copy it back, run ./sync.sh, commit."
  fi
  backup "$dest"
  echo "Rendering $src -> $dest"
  mv "$tmp" "$dest" && (( RENDERED++ ))
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
link_config "git/gitconfig-personal" "$HOME/.gitconfig.personal"
if ! git config --file ~/.gitconfig.local user.email &>/dev/null; then
  todo "Set your work git email: git config --file ~/.gitconfig.local user.email you@company.com"
fi
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
# when it's already done or its tool is missing, so re-running is cheap.
# ---------------------------------------------------------------------------
if [[ "$INSTALL_EXTRAS" == true ]]; then
  echo "Installing extras..."
  [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
  export PATH="$HOME/.local/bin:$PATH"

  # Agent CLIs (official installers)
  if command -v claude >/dev/null; then skipped "Claude Code CLI"
  else extra "Claude Code CLI" "curl -fsSL https://claude.ai/install.sh | bash" bash -c 'curl -fsSL https://claude.ai/install.sh | bash'; fi
  if command -v cursor-agent >/dev/null; then skipped "Cursor CLI"
  else extra "Cursor CLI" "curl -fsS https://cursor.com/install | bash" bash -c 'curl -fsS https://cursor.com/install | bash'; fi

  # Codex CLI comes as cxstatusline's patched build + wrapper (~/.local/bin/codex)
  if ! command -v cxstatusline >/dev/null; then
    failed "Codex CLI" "cxstatusline is missing (Brewfile npm entry, needs node): npm install -g cxstatusline, then re-run --extras"
  elif grep -qs cxstatusline-wrapper ~/.local/bin/codex; then
    skipped "Codex CLI (cxstatusline)"
  else
    extra "Codex CLI (cxstatusline install)" "cxstatusline install -y; 'cxstatusline doctor' explains what's wrong" cxstatusline install -y
  fi
  # Point the wrapper's renderer at turn-renderer.py (adds the per-turn timer).
  # `cxstatusline upgrade` regenerates the wrapper; re-run --extras afterwards.
  if grep -qs cxstatusline-wrapper ~/.local/bin/codex && ! grep -qs turn-renderer ~/.local/bin/codex; then
    extra "Codex turn timer (patch cxstatusline wrapper)" "Edit ~/.local/bin/codex: set CXSTATUSLINE_COMMAND='python3 ~/.config/cxstatusline/turn-renderer.py'" \
      sed -i '' "s#^CXSTATUSLINE_COMMAND=.*#CXSTATUSLINE_COMMAND='python3 $HOME/.config/cxstatusline/turn-renderer.py'#" ~/.local/bin/codex
  fi

  # Editor extensions
  for editor in "code:vscode:VS Code" "cursor:cursor:Cursor"; do
    cli="${editor%%:*}"; rest="${editor#*:}"; list="${rest%%:*}"; label="${rest#*:}"
    if ! command -v "$cli" >/dev/null; then
      failed "$label extensions" "$label isn't installed (or its '$cli' command isn't on PATH); install it, then re-run --extras"
      continue
    fi
    installed="${(L)$("$cli" --list-extensions 2>/dev/null)}"
    n_have=0
    while read -r ext; do
      [[ -z "$ext" ]] && continue
      grep -qixF "$ext" "$DOTFILES_DIR/local-extensions.txt" && continue
      if [[ "$installed" == *"${(L)ext}"* ]]; then (( n_have++ )); continue; fi
      extra "$label extension $ext" "$cli --install-extension $ext (it may not exist in ${label}'s extension store)" \
        "$cli" --install-extension "$ext"
    done < "$DOTFILES_DIR/$list/extensions.txt"
    (( n_have > 0 )) && skipped "$n_have $label extensions"
  done

  # Claude Code plugins: marketplaces + plugins listed in claude/settings.json
  if command -v claude >/dev/null; then
    have_markets="$(claude plugin marketplace list 2>/dev/null)"
    have_plugins="$(claude plugin list 2>/dev/null)"
    python3 -c "
import json, sys
s = json.load(open(sys.argv[1]))
if any(p.endswith('@claude-plugins-official') for p in s.get('enabledPlugins', {})):
    print('marketplace', 'anthropics/claude-plugins-official')
for m in s.get('extraKnownMarketplaces', {}).values(): print('marketplace', m['source']['repo'])
for p, on in s.get('enabledPlugins', {}).items():
    if on: print('plugin', p)" "$DOTFILES_DIR/claude/settings.json" | while read -r kind name; do
      if [[ "$kind" == marketplace && "$have_markets" == *"$name"* ]]; then
        skipped "Claude marketplace $name"
      elif [[ "$kind" == plugin && "$have_plugins" == *"$name"* ]]; then
        skipped "Claude plugin $name"
      elif [[ "$kind" == marketplace ]]; then
        extra "Claude marketplace $name" "claude plugin marketplace add $name" claude plugin marketplace add "$name"
      else
        extra "Claude plugin $name" "claude plugin install $name (run 'claude' once and /login first if it asks)" claude plugin install "$name"
      fi
    done
  fi

  # Third-party agent skills (source + name per line)
  if command -v npx >/dev/null; then
    while read -r source skill; do
      [[ -z "$source" ]] && continue
      if [[ -e "$HOME/.agents/skills/$skill" ]]; then skipped "skill $skill"; continue; fi
      extra "skill $skill ($source)" "npx skills add $source -g -s $skill -a '*'" \
        npx -y skills add "$source" -g -y -s "$skill" -a '*'
    done < "$DOTFILES_DIR/skills/third-party.txt"
  fi

  # terminal-browser's own agent skills/config
  command -v terminal-browser >/dev/null \
    && extra "terminal-browser setup" "terminal-browser setup (run it by hand to see its prompts)" terminal-browser setup

  # herdr plugin
  if command -v herdr >/dev/null; then
    if herdr plugin list 2>/dev/null | grep -q auto-title; then skipped "herdr Auto Title plugin"
    else extra "herdr Auto Title plugin" "herdr plugin install kryptamine/herdr-auto-title --yes (needs 'go' from the Brewfile)" \
      herdr plugin install kryptamine/herdr-auto-title --yes; fi
  fi

  # Xcode from the App Store isn't the active developer dir until selected (admin prompt)
  if [[ -d /Applications/Xcode.app && "$(xcode-select -p 2>/dev/null)" != /Applications/Xcode.app/* ]]; then
    echo "  Selecting Xcode and accepting its licence (admin prompt)..."
    if sudo xcode-select -s /Applications/Xcode.app/Contents/Developer && sudo xcodebuild -license accept; then
      ok "Xcode selected as developer directory"
    else
      failed "select Xcode" "sudo xcode-select -s /Applications/Xcode.app/Contents/Developer && sudo xcodebuild -license accept"
    fi
  fi

  # Macchiato: own fork, built from source (needs Xcode)
  if [[ -d /Applications/Macchiato.app ]]; then
    skipped "Macchiato"
  elif xcodebuild -version &>/dev/null; then
    src="$HOME/Repos/Macchiato"
    if clone_repo "$src" git@github-chrisrawstone:ChrisRawstone/Macchiato.git ChrisRawstone/Macchiato "${MACCHIATO_REPO:-}"; then
      extra "build Macchiato" "Open ~/Repos/Macchiato/Macchiato.xcodeproj in Xcode and build (Xcode may need to finish installing components)" \
        xcodebuild -project "$src/Macchiato.xcodeproj" -scheme Macchiato -configuration Release \
        -destination 'platform=macOS,arch=arm64' SYMROOT="$src/build" build \
      && extra "install Macchiato" "ditto ~/Repos/Macchiato/build/Release/Macchiato.app /Applications/Macchiato.app" \
        ditto "$src/build/Release/Macchiato.app" /Applications/Macchiato.app
    fi
  else
    todo "Macchiato needs Xcode: once Xcode is installed (App Store), re-run './init_script.sh --extras'. Or unzip Macchiato.app.zip from the backup"
  fi

  # AgentsCompare: own VS Code/Cursor extension (not on the Marketplace), built from source
  ac_targets=()
  for cli in code cursor; do
    command -v "$cli" >/dev/null || continue
    if "$cli" --list-extensions 2>/dev/null | grep -qix chrisrawstone.agentscompare; then skipped "AgentsCompare in $cli"
    else ac_targets+=("$cli"); fi
  done
  if [[ ${#ac_targets[@]} -gt 0 && -n "${SKIP_AGENTSCOMPARE:-}" ]]; then
    skipped "AgentsCompare (SKIP_AGENTSCOMPARE set)"
  elif [[ ${#ac_targets[@]} -gt 0 ]]; then
    ac="$HOME/Repos/AgentsCompare"
    if clone_repo "$ac" git@github-chrisrawstone:ChrisRawstone/AgentsCompare.git ChrisRawstone/AgentsCompare "${AGENTSCOMPARE_REPO:-}" \
       && extra "build AgentsCompare" "cd ~/Repos/AgentsCompare && npm ci && npm run package" \
            bash -c "cd '$ac' && npm ci --no-audit --no-fund && npm run package"; then
      vsix=$(ls -t "$ac"/agentscompare-*.vsix 2>/dev/null | head -1)
      for cli in "${ac_targets[@]}"; do
        extra "AgentsCompare in $cli" "$cli --install-extension $vsix" "$cli" --install-extension "$vsix"
      done
    fi
  fi

  # Azure CLI extensions
  if command -v az >/dev/null; then
    have="$(az extension list --query '[].name' -o tsv 2>/dev/null)"
    while read -r ext; do
      [[ -z "$ext" ]] && continue
      if [[ "$have" == *"$ext"* ]]; then skipped "az extension $ext"; continue; fi
      extra "az extension $ext" "az extension add --name $ext" az extension add --name "$ext" --yes
    done < "$DOTFILES_DIR/azure-cli-extensions.txt"
  fi
fi

# ---------------------------------------------------------------------------
# Recap
# ---------------------------------------------------------------------------
(( LINKED + RENDERED > 0 )) && ok "Configs: $LINKED linked, $RENDERED rendered"
(( MOVED_ASIDE > 0 )) && ok "$MOVED_ASIDE existing files moved aside as *.pre-dotfiles-$STAMP"

# Sign-ins only you can do, for what's actually installed
logins=()
command -v claude >/dev/null && logins+=("Claude Code: run 'claude', then /login")
[[ -d /Applications/Claude.app ]] && logins+=("Claude app")
[[ -d /Applications/ChatGPT.app ]] && logins+=("ChatGPT app (also signs in Codex)")
[[ -d /Applications/Cursor.app ]] && logins+=("Cursor")
[[ -d /Applications/1Password.app ]] && logins+=("1Password (Secret Key, or 'Set up another device' from your phone)")
[[ -d "/Applications/Google Chrome.app" ]] && logins+=("Chrome (turn on sync)")
[[ -d /Applications/Notion.app ]] && logins+=("Notion")
command -v gh >/dev/null && ! gh auth status &>/dev/null && logins+=("GitHub CLI: gh auth login")
command -v az >/dev/null && ! az account show &>/dev/null && logins+=("Azure CLI: az login")
# Only after an install run: the script can't tell whether an app is already signed in
if [[ "$INSTALL_BREW" == true || "$INSTALL_EXTRAS" == true ]] && (( ${#logins[@]} > 0 )); then
  signin="Sign in (skip any you already did):"
  for l in "${logins[@]}"; do signin+=$'\n      - '"$l"; done
  todo "$signin"
fi

echo
echo "=================================== Recap ==================================="
if (( ${#DONE[@]} > 0 )); then
  echo "Done (${#DONE[@]}):"
  for d in "${DONE[@]}"; do echo "  ✓ $d"; done
else
  echo "Nothing to do: everything was already in place."
fi
if (( ${#SKIPPED[@]} > 0 )); then
  echo "Already there, skipped (${#SKIPPED[@]}):"
  echo "  ${(j:, :)SKIPPED}" | fold -s -w 78 | sed '2,$s/^/  /'
fi
if (( ${#FAILED[@]} > 0 )); then
  echo "FAILED (${#FAILED[@]}):"
  for f in "${FAILED[@]}"; do
    echo "  ✗ ${f%%$'\t'*}"
    echo "      fix: ${f#*$'\t'}"
  done
fi
if (( ${#TODO[@]} > 0 )); then
  echo "Needs you (${#TODO[@]}):"
  for t in "${TODO[@]}"; do echo "  → $t"; done
fi
[[ "$INSTALL_EXTRAS" != true ]] && echo "Tip: --extras installs editor extensions, agent CLIs, plugins, skills and own apps."
echo "Full log: $LOG"
echo "Everything is safe to re-run: './init_script.sh --all' only redoes what's missing."
echo "============================================================================="

if (( ${#FAILED[@]} > 0 )); then
  echo "Finished with ${#FAILED[@]} failure(s). Fix them (see above) and re-run."
  exit 1
fi
echo "Setup complete! Open a new terminal (or run 'source ~/.zshrc')."
