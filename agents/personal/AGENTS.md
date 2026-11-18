# Personal projects

This folder (`~/Repos/personal`) and `~/scratch` are personal: hobby projects and life admin. Work lives in
`~/Repos/work`; keep the two apart, and never bring work accounts, tools or context in here.

# Repos

What each repo in `~/Repos/personal` is, so you know where something lives. For details and status, read the repo's
own `AGENTS.md` or `README.md`. Update this list when a repo is added, removed or changes purpose.

- `notes` (GitHub `ChrisRawstone/notes`, private): my Obsidian vault for all personal projects, one folder per
  project, synced to the iPhone through GitHub (obsidian-git).
  I read it in Obsidian while agents work: before writing or checking any note, read `notes/AGENTS.md` and pass its
  rules to subagents. Edit notes as files, check them with `notes/.tools/render/render.sh`, and never drive, open or
  focus an Obsidian window.
- `sites`: small private websites on nordaicloud.com behind one shared login (hub, home, packages). New small sites go here.
- `home-assistant`: my Home Assistant (OptiPlex, `homeassistant.local`), its config exports and scripts, and the
  plants site (`plants/`, Next.js on Railway).
- `trip-planner` (GitHub `ChrisRawstone/trip-radar`): Trip Radar (Next.js on Railway, https://trips.nordaicloud.com,
  also https://flights.nordaicloud.com): weekend trips for two: cheapest flights (Kiwi, Google Flights, Ryanair, SAS,
  Wizz), stays (trivago, Airbnb, Google Hotels, Agoda), guides with prices, the total cost, a 3-hourly price watch.
- `flights`: the old local-only copy of the same project, kept while another session finishes work there. New work goes
  in `trip-planner`.
- `bolig` (GitHub `ChrisRawstone/bolig`): Bolig (Next.js on Railway, https://bolig.nordaicloud.com): Copenhagen
  ejerlejligheder for sale, fair value from registered sales, Claude's read and score per flat (Mac launchd job), market. Also `/kontor` (https://kontor.nordaicloud.com, office pages only): office leases
  for Mom's company (Ejendomstorvet, Lokalebasen, Jeudan) with the same Claude read.
- `marketplace-mcp`: the `marketplace-railway` MCP server (DBA, Blocket, Finn, Tradera, Amazon, PriceRunner and
  more), local over stdio and hosted on Railway.
- `edge-lab` (GitHub `ChrisRawstone/edge-lab`, private): hobby prediction-market trading lab (Polymarket/Kalshi weather markets): research, backtests, a guarded
  paper/live bot.
- `stocks` (GitHub `ChrisRawstone/stocks`, private): my stock trading at Saxo (aktiesparekonto): plan, trade log,
  a scorecard against an index fund, a Saxo simulator script.
- `aps-autopilot`: local app for the yearly obligations of my holding ApS (bookkeeping, tax, annual report, filing).
- `ikea-to-apple-home`: copies device names and rooms from the IKEA DIRIGERA hub into Apple Home.
- `dev-setup`: dotfiles, apps and agent configs for this Mac, and the source of these `AGENTS.md` files.
- `herdr`, `herdr-patched`: my fix branches of the Herdr terminal multiplexer (upstream `herdrdev/herdr`).
- `Macchiato`: macOS menu bar app that keeps the Mac awake.
- `AgentsCompare`: VS Code/Cursor extension for reviewing everything a branch changed.

`~/scratch` is for life admin and one-off questions; its memory holds notes on my company, home, plants and Mac.

# Notes in Obsidian

When I ask you to explain something, understand a codebase or technology, give an overview, plan or status, or compare
things to buy or choose, write it as a note in my Obsidian vault with the `notes` skill (diagrams and charts welcome),
then give me a short answer in chat with a link to the note. Skip it for quick one-line answers and plain code work.

# Do it yourself

Set things up yourself instead of giving me manual steps: app settings, hotkeys, plugins, config files, scheduled
jobs, accounts. Find the way first (the app's config files, its CLI or scripting API such as `obsidian eval`,
`defaults write`, an official API), do it, and read the setting back to check. Hand me a step only when it truly needs
me (Touch ID or a login prompt, a payment, something physical, or something another rule forbids, like driving my open
Obsidian window), and say why.

# Git and GitHub

Commit as `ChrisRawstone <christian.raasteen@outlook.com>` with the GitHub account ChrisRawstone. The gitconfig sets
both for this folder, and `gh` picks the account by folder. Use `dr.rawstone@outlook.com` instead only when I ask to
stay anonymous (`git -c user.email=dr.rawstone@outlook.com commit …`).

The `/pr` skill is off in every repo here (`"pr": "off"` in `skillOverrides`), so the global "open every PR with `/pr`"
rule doesn't apply: commit or push only when I ask, and give a new personal repo the same override. Exception: in `dev-setup`, commit and push your own
changes right away, even when it holds my unrelated uncommitted or staged work; commit only your files and hunks
(`git commit -- <paths>`, or a temporary index for a file we both changed) and leave mine as they were.

# MCP servers and connectors

Personal MCP servers (`marketplace-railway`, `home-assistant`, `railway`, `apify`, `ms365-personal`, `kiwi`) live in
`~/Repos/personal/.mcp.json`, which every repo and worktree below it picks up (`~/scratch` has them at local scope).
Add a new personal server there, never at user scope, so work sessions never see it. Each personal folder's
`.claude/settings.local.json` enables the cloudflare/homeclaw plugins, denies the work connectors (Notion, Slack, HS
CV Machine, HS Proposal Search, Databricks) and hides the Halfspace skills (`hs-ai-skills@synced`,
`halfspace-slides`): give a new personal repo a copy of `~/scratch/.claude/settings.local.json`.

# Hobby project domains

Put every personal hobby project's site or service on a subdomain of my **nordaicloud.com** (DNS and registrar at
Cloudflare; existing: `shop.`, `aps.`, `home.`), never on a bare `*.up.railway.app` or similar default address. For
Railway: `railway domain <sub>.nordaicloud.com`, then add its CNAME (DNS only, not proxied) and `_railway-verify` TXT
in Cloudflare, check HTTPS, and remove the generated Railway domain. A password-protected site gets a real login form
(`autocomplete="username"` / `"current-password"`, not browser Basic auth, which 1Password can't fill) and a 1Password
**Login** item with that site's URL, so 1Password offers it there.

# Shopping

For finding, buying or pricing a product, used or new, use both the `marketplace-railway` MCP server (DBA, Blocket,
Finn, Tradera, Facebook Marketplace, eBay, Amazon, AliExpress, PriceRunner, Prisjagt and more) and, for a general search (the best deal
or price on a product, not one named site or listing), your own web searches in parallel. The MCP has blind spots (Komplett, brand stores, Temu, deal sites, local shops, forums), so never
call a price the best or a product the right one from the MCP alone; say which sources you searched.
Use web search and fetch for specs and reviews too.
Check the photos (all of them) of every product you shortlist or recommend, not just the text: sellers often put the
facts there (variant comparison tables, what's included, battery, compatibility, size), especially on AliExpress and
Amazon. Do it through the `shopper` subagent, several listings per call, never `get_photos` in the main session: photos
are the biggest context cost.

# Product photos on pages

When a page or site recommends products, show 2–3 photos of each recommended product next to it (the exact variant and
colour, shrunk and stored in the project, with a caption and a source link), so I can see what it looks like. Let the
`shopper` subagent pick and check the photos.
