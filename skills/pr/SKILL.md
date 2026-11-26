---
name: pr
description: Open or update a PR the house way. Merge the base branch in, review with /pre-pr, push, test-merge against the other open PRs to set a merge order, and open the PR with an ultra-short title and description. Use whenever a branch is ready for a PR or a PR needs updating, or for "/pr", "open a PR", "push this".
argument-hint: "[base branch, default main]"
---

# PR

Stop and ask the user whenever a step fails or needs a judgment call. Never push `main`.

## 1. Merge the base in

```bash
git fetch origin --quiet
base=${1:-main}   # a stacked branch's base is its parent branch
git merge --no-edit "origin/$base"
```

Resolve conflicts by keeping both sides' intent; ask the user when that isn't clear. Then run
the project's checks (`just check`, or what `AGENTS.md` names).

## 2. Review

Run the `/pre-pr` skill with `origin/$base`, and fix the findings the user picks.

## 3. Push

Before every push, run `/pre-pr`'s step 6, so commits added since the review get reviewed too.
Ask the user before the first push of the branch, then `git push -u origin HEAD`.

## 4. Merge order

List the other open PRs. On Azure DevOps, take org, project and repo from
`git remote get-url origin` (`git@ssh.dev.azure.com:v3/<org>/<project>/<repo>`):

```bash
az repos pr list --org "https://dev.azure.com/$org" --project "$project" --repository "$repo" \
  --status active -o json --query "[].{id:pullRequestId,title:title,src:sourceRefName,tgt:targetRefName}"
```

On GitHub, use `gh pr list --json number,title,headRefName,baseRefName`. Test-merge this branch
with each one, without touching any working folder:

```bash
git merge-tree --write-tree --name-only "origin/$their_branch" HEAD   # exit 1: conflicts, files listed
```

- No conflicts: say nothing about order.
- Conflicts: this PR merges after the older one. Name it and the files, e.g.
  `Merge after !2151 (both change search.py); this branch takes main again once it lands.`
- A PR stacked on this branch merges after it; one this branch is stacked on, before it.

## 5. Open or update the PR

Title: one conventional-commit line of about 50 characters. Description: one to three short
bullets on what changed and why, plus the merge-order line from step 4 if there is one. No
headings, test plans or file lists. Show the user the title and description before creating it:

```bash
az repos pr create --org … --project … --repository … --source-branch "$branch" \
  --target-branch "$base" --title "…" --description "…"
```

(`gh pr create --base "$base" --title … --body …` on GitHub.) When the PR already exists, update
its merge-order line instead (`az repos pr update --id … --description …`).
