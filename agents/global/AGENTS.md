# Worktrees

Manage Git worktrees with worktrunk (`wt`), never with raw `git worktree`, in every repository:
`wt switch --create <branch> [--base <ref>]` to create one (its hooks copy `.env` and set up
dependencies), `wt switch <branch>` to move into one, `wt list` to see them, and `wt remove` to
remove one. The worktrunk plugin's `/worktrunk` skill covers configuration.

# Web apps

Look at and test web apps in a headless browser, in every repository: the `agent-browser` that
terminal-browser bundles (`/opt/homebrew/Caskroom/terminal-browser/*/terminal-browser/agent-browser/bin/agent-browser
--session headless open|snapshot|click|screenshot …`), then Read the screenshots. Start the dev
server in the background only if nothing answers on its port. Don't open panes in Herdr for it:
use the `web-preview` skill (a live browser pane) only when I ask to watch. Don't use the Chrome
extension unless I ask. A project's `AGENTS.md` names its dev server command and port.

When a terminal-browser is already open in Herdr on the app you're working on (a worktree's
`ctrl-s shift-f` stack opens one on its `WEB_PORT`), use that one, not a headless or new browser,
so I see what you do:

- Find it: `terminal-browser ls --all --json` lists each browser's `key`, `cdpPort` and tab `url`s;
  pick the one whose URL has the app's port. None open: fall back to headless as above.
- Drive it: `terminal-browser action --browser <key> -- snapshot -i | click @e3 | fill @e2 'text' |
  get title | get url | eval 'js' | screenshot <abs.png> | open '<url>'`, then Read the screenshot.
  Snapshot again after any page change (refs change), quote URLs (zsh globs `?`), and end with
  `terminal-browser action --browser <key> done` to hand control back.
- Always pass `--browser <key>`: in herdr-app, terminal-browser can't tell which pane it's in, so a
  bare `action` fails ("no terminal browser in this terminal tab"). Don't use `--split` or
  `new-tab` there.
- `could not connect agent-browser` means the `~/.local/bin/terminal-browser` shim (dev-setup) isn't
  first on PATH: use `/opt/homebrew/Caskroom/terminal-browser/*/terminal-browser/agent-browser/bin/agent-browser
  --cdp <cdpPort> …` instead.

# Feedback

Never draft or send feedback or bug reports to Anthropic (the SendFeedback tool or anything like
it), in any session.

# PRs

Open or update every PR, in every repository, with the `/pr` skill: it merges the base branch
in, runs `/pre-pr` (Fable 5.2, Opus 5.5 Ponytail and GPT-6 Astra review at high effort, a
checker verifies, I pick the fixes), pushes, and works out a merge order against the other open
PRs.

# Commit and PR text

Keep them ultra short, in every repository. Commit messages: one subject line of about 50
characters (the conventional-commit prefix included), no body unless the why isn't obvious, and
then one line. PR titles: one such line. PR descriptions: one to three short bullets on what
changed and why; no headings, summaries, test plans or file lists.

# Secrets

**1Password is the one place for every API key, token, password or secret**, in every repository and session. My
**Employee** vault (halfspace.1password.com) holds them; the project gets its copy too where it needs one (e.g. the
macOS Keychain, an app's settings).

- **Look before you ask.** Before asking me for a key or sending me to create one, search all vaults:
  `op item list --format json`, matched on the service, project and words like "api key" / "token" (titles and
  notes). Use what's there.
- **Save what you get.** Any secret I paste into chat, that you generate, or that a setup creates, goes into
  1Password right away, before it's used, so nobody has to ask for it again. Name it "<Project> – <what it is for>"
  (e.g. "Home Assistant – Spotify Soloist API key"), category API Credential (or Login/Password), with the URL where
  it was made and a one-line note on what uses it. If a paste looks garbled (a stray character), save the cleaned
  value and say so in the note.
- **Write it without showing it:** put a JSON template in a chmod-600 file in the scratchpad,
  `op item create --vault Employee --template <file> < /dev/null`, then delete the file. (`op` refuses a piped
  template: without `--category` it errors, and with `--template /dev/stdin` it says "template and stdin at the same
  time"; a failed try can leave an empty "Untitled" item, so check for one and delete it.)
- **Check it** by item ID: `op item get <id> --fields <field> --reveal` compared against the source in a shell test
  (`[ "$(…)" = "$src" ]`), never printed.
- **Few `op` calls: each one can make me approve in 1Password** (Touch ID; every Bash call is a new session, so
  approvals don't carry over). Do the search, create, check and use of a secret in **one** Bash command (e.g.
  `K=$(op item get <id> --fields credential --reveal)` and the command that needs it, in the same call), search
  with a single `op item list` and filter its JSON locally, and never call `op` again for something already known
  in this session (keep the item ID).
- Record the item's name (not the value) in the project's `AGENTS.md`, next to whatever uses it.

# Links and sources

Give a clickable link for every product, shop, price and factual claim, to where it came from: look it up before
answering, and if no link can be found, say so. Subagent reports count too: when one names a price or shop without its
URL, get the link before answering. Never paper over a missing link with a search URL. Check legal, tax and other
factual claims (especially Danish rules) against official sources (erhvervsstyrelsen.dk, skat.dk, retsinformation.dk)
before giving them, cite the official URL, and mark anything that couldn't be verified.

# Instruction files

Instruction files are `AGENTS.md`, never `CLAUDE.md`, so they work with any agent (Claude Code, Codex and others). Where
a tool needs its own name (Claude Code's `~/.claude/CLAUDE.md`), make it a symlink to the `AGENTS.md` source. The
sources live in dev-setup `agents/`: `global/` (this file, every session), `personal/` (linked as
`~/Repos/personal/AGENTS.md` and `~/scratch/AGENTS.md`) and `work/` (linked as `~/Repos/work/AGENTS.md`). Repos go in
`~/Repos/work` or `~/Repos/personal`, never directly in `~/Repos`.

# Copy-paste text

When I will paste text somewhere (form answers, drafts, messages, emails), write it as plain paragraphs under a bold
label, in every project. Never use markdown blockquotes (`>`) for it: the terminal draws a vertical bar and italics
that get in the way when copying.

# Blocked web pages

A bot check, 403, 429, captcha, "Just a moment", security checkpoint, empty JS page or IP block is never a reason to
give up, in every project and session. Use the `blocked-fetch` skill (`~/.claude/skills/blocked-fetch/SKILL.md`) and
go down its ladder: its `fetch.py` (curl_cffi browser fingerprints, headless Chrome, Apify, in one command), an
archive copy or API, then Codex (the `codex:codex-rescue` agent). Only call a page unreadable after that, saying what
each step returned. Pass this to subagents that fetch pages. Public docs often also live on GitHub (`gh api`).

# Investigate

When I say "investigate" (anywhere in a message, in every repository and session), use the
`/investigate` skill: three parallel agents with different angles (prior art, best practice,
hands-on), online research, the simplest solution that works.

# File paths in replies

Write every local file path I might open (screenshots, code, logs) as a markdown link to its absolute path, in
every project: `[home-before.png](/private/tmp/.../home-before.png)`, with `:line` when it helps
(`[server.py:12](/Users/.../server.py:12)`). Claude Code draws it as a `file://` link, and Ctrl-click in Herdr
opens it: code in its repo's Cursor window, images/PDFs in Preview, the rest in their default app (plugin
`open-in-cursor` in dev-setup). Bare paths aren't clickable; spaces in a path need %20.

# Missing access

When a permission, login, token, key or other access is missing (it blocks a task or cuts it short), first try to get
it yourself, in every repository and session. If you can't, flag it right away as a bold line at the top of your
reply, never as a side note at the end: **⚠️ MISSING ACCESS: <what> — blocks <what>; fix: <what would solve it>**.
Subagent reports count too.
