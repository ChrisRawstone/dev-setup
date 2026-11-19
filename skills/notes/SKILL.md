---
name: notes
description: Write explanations, overviews and comparisons as notes in the owner's Obsidian vault (~/Repos/personal/notes) instead of only in chat, with diagrams and charts. Personal projects only (~/Repos/personal, ~/scratch), never work. Use whenever the owner asks to explain, understand or learn something (a codebase, a technology, a concept), wants an overview, plan, status or summary, or compares options to buy or choose (shopping, products, services), and after every product search with the marketplace-railway MCP; also for research results worth keeping. Skip for quick one-line answers and plain code changes.
---

# Notes in the vault

Things the owner wants to understand, compare or come back to go in the Obsidian vault at
`~/Repos/personal/notes` (private GitHub `ChrisRawstone/notes`, synced to the iPhone). The chat gets a short answer
and the note's link. Personal sessions only: never in `~/Repos/work`.

## 1. Rules first

Read `~/Repos/personal/notes/AGENTS.md` before writing: it has the vault's layout and the rules for working while the
owner has Obsidian open. In short: edit notes as files, check them with `.tools/render/render.sh`, never open, drive
or focus an Obsidian window. Pass those rules on to any subagent that writes notes.

## 2. Where it goes

Every folder works the same way, so the owner can find anything in two clicks:

```
Home.md                      table of every folder + recently updated
<Folder>/<Folder>.md         the folder's home note: start here (overview, status, table of its notes)
<Folder>/<Note>.md           a few core notes the owner reads
<Folder>/Reference/          long detail notes: experiments, research, code walk-throughs
<Folder>/_generated/         CSVs written by scripts
<Folder>/attachments/        images
```

- A project (a repo in `~/Repos/personal`) gets `<Project>/` (e.g. `Edge Lab/`, `Stocks/`); codebase explanations go
  in its `Reference/`.
- Shopping goes in `Shopping/`, learning a technology or concept in `Learn/` (general explainers live here, not
  inside a project, and projects link to them), and life admin in `Life/`.
- A new folder gets its home note and a row in `Home.md`. A new note gets a row in its folder's home note table
  (note, one line on what's in it).

## 3. Keep it lean

The owner should never feel lost or buried. Before adding anything:

- **Update, don't add.** Search the vault (`grep -ril`) and extend the existing note. Two notes on one topic get
  merged; fix the links (`[[...]]`) that pointed at the old one.
- **The home note tells the story.** In plain words: the goal, what was tried and what came out, what's running now,
  what's next. Keep it current: when work moves on, rewrite its status, don't append to it.
- **Budgets:** a home note fits on about two screens; a core note stays under about 1,500 words. Detail beyond that
  goes in `Reference/` with a summary at the top.
- **Delete what's stale:** dashboards for stopped bots, superseded plans, duplicate explainers.

## 4. How it looks

Follow [style.md](style.md): the owner's preferences for structure, diagrams, charts and tone. When the owner says
what they like or dislike about a note, update `style.md` (this skill lives in dev-setup `skills/notes/`) so every
later note follows it.

## 4b. Shopping notes

Any product search (every use of the `marketplace-railway` MCP, by the main session or a subagent) gets a note in
`Shopping/`, or updates the existing one on that product, plus its row in `Shopping/Shopping.md`. Layout:

1. `[!summary]` callout: the pick, the price and where, the date checked.
2. **Options table**: every real option found, not only the winner: a **photo column right after `#`** with one
   thumbnail per row (`![[file.jpg\|120]]`, the pipe escaped inside a table; owner's request 2026-11-19), name, price
   in DKK (with shipping/import to Denmark), shop as a link, key facts, verdict. Then a short **ruled out** list (what was checked and why it's out).
3. **Photos**: 1–3 per option in a table (`![[file.jpg|170]]`), stored in `Shopping/attachments/` (shrunk to ~600 px,
   under ~100 kB, named `<topic>-<product>-<n>.jpg`), each with a caption and a source link. Use the shopper
   subagent's checked photos; for others take the shop's product images.
4. **Not checked**: what's still open.

Work in passes: create the note as soon as the first results are in, update it as each agent reports back, and when
the last one is back rewrite the summary and ranking, since a late find can change the pick. Every price, shop and
claim gets its link.

## 5. Check, then hand over

1. Render it: `~/Repos/personal/notes/.tools/render/render.sh "<Folder/Note.md>" <scratchpad>/note.png`, Read the PNG
   and fix anything broken (a blank chart, a raw code block, an error in the JSON report). Look at the whole page.
2. Don't commit by hand: obsidian-git commits and pushes within 10 minutes. Commit and push yourself only if the
   owner needs it on the phone right away and asks.
3. In chat: three to six lines with the answer, then the note as a clickable link the owner opens themselves:
   `[Note title](obsidian://open?vault=notes&file=<Folder>%2F<Note>)` (URL-encode the path, no `.md`), plus the file
   path link. Never run `open obsidian://…` yourself.
