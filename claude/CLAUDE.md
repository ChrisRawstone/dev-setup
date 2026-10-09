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

# Feedback

Never draft or send feedback or bug reports to Anthropic (the SendFeedback tool or anything like
it), in any session.
