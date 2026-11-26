---
name: pre-pr
description: Review a branch before it is pushed for a PR. Three reviewers run in parallel at high effort (Fable 5.2, Opus 5.5 with Ponytail, GPT-6 Astra through Codex) while the change is run and measured, then a fresh checker verifies, merges and ranks their findings, and the user picks what to fix. Also re-reviews commits added since the last review before a push. Use before pushing a branch to open a PR, or for "/pre-pr", "review before the PR", "review my branch".
argument-hint: "[base ref, default origin/main]"
---

# Pre-PR review

Every reviewer reads `criteria.md` in this skill's folder. Nobody edits files until the user has
picked findings.

## 1. Scope

```bash
git status --porcelain    # must be empty
git fetch origin --quiet
base=$(git merge-base "${1:-origin/main}" HEAD)
git diff --stat "$base" HEAD
reviewed=$(git rev-parse HEAD)
git config "branch.$(git branch --show-current).prereviewed" "$reviewed"
```

If the tree is dirty, ask the user to commit or stash first: a stray or rejected edit would be
reviewed as part of the branch. Use the argument as the base when one is given (a stacked
branch reviews against its parent). If the diff is empty, say so and stop. Set `out` to a new
folder in your scratchpad.

## 2. Three reviewers, in one message

Each gets the repo path, `$base`, and the path to `criteria.md`, and returns findings in its
format. None of them gets this conversation, so the author's reasoning doesn't sway them.

Run each reviewer at high effort, as set below; don't fall back to other models or levels.

- **Fable:** an `Agent` (general-purpose) with `model: "fable"` and `effort: "high"`: "Review
  `git diff <base> HEAD` in <repo> following <criteria.md>. Use your normal judgment; do not
  apply Ponytail or any other review style. Run a test or a snippet when it settles a doubt.
  Don't edit files."
- **Ponytail:** an `Agent` (general-purpose) with `model: "opus"` and `effort: "high"`:
  "Invoke the `ponytail:ponytail-review` skill on `git diff <base> HEAD` in <repo>, also cover
  <criteria.md>, and give the findings in its checklist's output format. Don't edit files."
- **Astra** (GPT-6 Astra through Codex, a different model, so different blind spots), with Bash
  in the background:

  ```bash
  codex --search exec -m gpt-6-astra -c model_reasoning_effort=high -s read-only \
    -C "$repo" -o "$out/astra.md" \
    "Hunt for bugs in git diff $base HEAD: what input, data, state or rollout breaks it, and what does it assume that isn't true? Review following $criteria. Don't edit files." </dev/null
  ```

Save the two agents' replies to `$out/fable.md` and `$out/ponytail.md`. If a reviewer fails,
carry on with the others and say which one is missing.

## 3. Run it and measure

While the reviewers work, exercise the change yourself and write what you ran and what it
showed to `$out/run.md`:

- Everything CI runs: read the pipeline file (`azure-pipelines.yml`, `.github/workflows/`) and
  run its checks locally, including `pre-commit run --all-files` when the repo has it.
- The e2e, integration or live tests whose code or feature the diff touches.
- Each entry point the diff changes (a CLI, server or job): start it once.
- Web changes: one real use of the changed screen in the headless browser.
- Data changes: row counts and distinct values of new or changed columns on dev data, before
  and after. Ask the user before running anything that writes to shared tables.

A failing check, or a test the diff touches that is red or skipped, is a finding (`found by:
run`) unless the user already knows why.

## 4. Checker

A fresh `Agent` (general-purpose) reads the reviewers' files, `$out/run.md` and the code: "For
each finding, open the code and check it; run a test or command when that settles it. Drop a
finding only when you can show it is wrong (say how). Merge duplicates and note which reviewers
found each. Return the confirmed findings ranked most severe first, in <criteria.md>'s format
plus `found by:`. Then list, one line each, findings that are real but minor and ones you could
neither confirm nor disprove, and one line per dropped finding with the evidence."

## 5. Hand over

Show the user the confirmed findings, numbered, one or two lines each, with `file:line` and
who found it, then the minor-or-unconfirmed list, numbered on, and how many were dropped. Ask
which to fix. Fix only those, then run the project's checks (`just check` or what `AGENTS.md`
names). Never push without the user's go.

After the user picks, append one line per finding, dropped ones too, to
`~/.local/state/pre-pr/log.tsv` (`date  repo  found-by  kind  fixed|skipped|dropped  title`),
so we can see later which reviewer is worth its cost.

## 6. Before each push: review what's new

Commits made after the review (fixes included) haven't been reviewed. Before any push:

```bash
reviewed=$(git config "branch.$(git branch --show-current).prereviewed")
git log --oneline "$reviewed"..HEAD
```

- Nothing new: push.
- No reviewed commit recorded, or a base merge among the new commits
  (`git rev-list --merges "$reviewed"..HEAD`): run the full review from step 1.
- Otherwise: run Astra alone with `$reviewed` in place of `$base`, so it reviews only the new
  commits (Fable the same way if Codex fails), and the step 3 checks they touch; then steps 4
  and 5, and record the new HEAD as `prereviewed`. Fixes from this round get the project's
  checks, not another round.
