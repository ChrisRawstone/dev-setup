---
name: web-preview
description: Run a web app's dev server and show the app live in the user's Herdr layout — server logs top right, a real browser below them — then look at and click through it. Use only when the user asks to watch the app or open it in Herdr (HERDR_ENV=1); otherwise check UIs in a headless browser.
---

# Web preview

Inside Herdr, show the web app where the user can watch it, beside your pane:

```
┌──────────────┬───────────┐
│              │ web logs  │
│  you         ├───────────┤
│              │  browser  │
└──────────────┴───────────┘
```

Check `test "${HERDR_ENV:-}" = 1` first. Outside Herdr, say so and use what the user asks for.

## Start it

1. Find the dev server command and its URL. Look in this order: the project's `AGENTS.md` or
   `CLAUDE.md` (a "Dev server" line), the `justfile`, then `package.json` scripts. Ports often
   come from `.env` (`WEB_PORT=…`); read the value rather than assuming a default.
2. Run, from the directory the server should run in (a worktree's own directory, when there is one):

   ```bash
   ~/.agents/skills/web-preview/bin/web-preview --cmd "just web" --url 16425 --cwd "$PWD"
   ```

   It makes the two panes (or reuses them, found by their labels), starts the server, waits for the
   URL to answer and opens it in `terminal-browser`. It prints JSON with the pane ids and CDP port.
   A server already answering on the URL is not started again.

## Drive and look

Use `~/.agents/skills/web-preview/bin/ab`, an `agent-browser` attached to that browser:

```bash
~/.agents/skills/web-preview/bin/ab snapshot -i          # interactive elements with @refs
~/.agents/skills/web-preview/bin/ab click @e8
~/.agents/skills/web-preview/bin/ab fill @e3 "soil investigation"
~/.agents/skills/web-preview/bin/ab press Enter
~/.agents/skills/web-preview/bin/ab open http://localhost:16425/?q=x
~/.agents/skills/web-preview/bin/ab screenshot <scratchpad>/step.png   # then Read the image
```

Judge layout from screenshots, not from snapshots alone. Read the server's output with
`herdr pane read <logs_pane> --source recent-unwrapped --lines 80` when something fails.

Keep `render.fps=30` in `terminal-browser config` (the display's 120 Hz floods Ghostty through
Herdr). Leave `render.presenter` on auto: `patched` is faster but leaves smeared, doubled bits on
screen. `render.transport=shared` makes no difference under Herdr. Typing still lags in a large
pane; the pane is for watching, and the user types in a normal browser.

The page renders small in a narrow pane. Tell the user they can click into the browser pane and
press ctrl+= to zoom; widen it with `herdr pane resize --pane <browser_pane> --direction left`.

## Stop it

Leave it running while the user is working on the UI. When asked to stop:
`~/.agents/skills/web-preview/bin/web-preview --stop` (stops the server, closes both panes).
