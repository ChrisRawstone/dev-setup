---
name: notes
description: Write explanations, overviews and comparisons as notes in the owner's Obsidian vault (~/Repos/personal/notes) instead of only in chat, with diagrams and charts. Personal projects only (~/Repos/personal, ~/scratch), never work. Use whenever the owner asks to explain, understand or learn something (a codebase, a technology, a concept), wants an overview, plan, status or summary, or compares options to buy or choose (shopping, products, services); also for research results worth keeping. Skip for quick one-line answers and plain code changes.
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

- A project (a repo in `~/Repos/personal`): `<Project>/` (e.g. `Edge Lab/`, `Bolig/`), its home note `<Project>.md`.
  Codebase explanations go in `<Project>/Explainers/`.
- Shopping and product choices: `Shopping/<Thing>.md` (e.g. `Shopping/Robot vacuum.md`).
- Learning a technology or concept: `Learn/<Topic>.md`.
- Life admin (`~/scratch` questions worth keeping): `Life/<Topic>.md`.

Before writing, search the vault (`grep -ril` on the topic) and update the existing note instead of making a twin.
Link new notes from the folder's home note (create `Shopping.md`, `Learn.md`, `Life.md` home notes on first use) and
from `Home.md` for a new folder.

## 3. How it looks

Follow [style.md](style.md): the owner's preferences for structure, diagrams, charts and tone. When the owner says
what they like or dislike about a note, update `style.md` (this skill lives in dev-setup `skills/notes/`) so every
later note follows it.

## 4. Check, then hand over

1. Render it: `~/Repos/personal/notes/.tools/render/render.sh "<Folder/Note.md>" <scratchpad>/note.png`, Read the PNG
   and fix anything broken (a blank chart, a raw code block, an error in the JSON report). Look at the whole page.
2. Don't commit by hand: obsidian-git commits and pushes within 10 minutes. Commit and push yourself only if the
   owner needs it on the phone right away and asks.
3. In chat: three to six lines with the answer, then the note as a clickable link the owner opens themselves:
   `[Note title](obsidian://open?vault=notes&file=<Folder>%2F<Note>)` (URL-encode the path, no `.md`), plus the file
   path link. Never run `open obsidian://…` yourself.
