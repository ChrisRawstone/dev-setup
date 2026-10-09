#!/usr/bin/env bash
# ─────────────────────────────────────────────
# start-issue  <issue-number>
#
# 1. Fetches the GitHub issue via gh cli
# 2. Creates a git worktree at ~/source/.worktrees/<owner-repo>/issue-<N>
# 3. Opens opencode in that worktree with a
#    structured planning prompt pre-loaded
# ─────────────────────────────────────────────

set -euo pipefail

# ── helpers ──────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'
info() { echo -e "${GREEN}▸${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC}  $*"; }
error() {
  echo -e "${RED}✗${NC}  $*" >&2
  exit 1
}

# ── args ─────────────────────────────────────
NO_LAUNCH=0
ISSUE_NUMBER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --no-launch)
    NO_LAUNCH=1
    shift
    ;;
  -h | --help)
    cat <<'USAGE'
Usage: start-issue [--no-launch] <issue-number>

Options:
  --no-launch   Prepare issue branch/worktree/prompt without launching opencode
  -h, --help    Show this help message
USAGE
    exit 0
    ;;
  -*)
    error "Unknown option: $1"
    ;;
  *)
    if [[ -n "$ISSUE_NUMBER" ]]; then
      error "Only one issue number is supported."
    fi
    ISSUE_NUMBER="$1"
    shift
    ;;
  esac
done

[[ -z "$ISSUE_NUMBER" ]] && error "Usage: start-issue [--no-launch] <issue-number>"

# ── sanity checks ────────────────────────────
command -v gh &>/dev/null || error "'gh' not found. Install: https://cli.github.com"
command -v git &>/dev/null || error "'git' not found."
command -v jq &>/dev/null || error "'jq' not found."
if [[ "$NO_LAUNCH" -eq 0 ]]; then
  command -v opencode &>/dev/null || warn "'opencode' not found in PATH — you may need to launch it manually."
fi

git rev-parse --is-inside-work-tree &>/dev/null || error "Not inside a git repository."
REPO_ROOT=$(git rev-parse --show-toplevel)

REPO_SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
if [[ -z "$REPO_SLUG" ]]; then
  REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
  REPO_SLUG=$(echo "$REMOTE_URL" | sed -E 's#^git@[^:]+:##; s#^https?://[^/]+/##; s#\.git$##')
fi
if [[ -z "$REPO_SLUG" ]]; then
  REPO_SLUG=$(basename "$REPO_ROOT")
fi

REPO_KEY="${REPO_SLUG//\//-}"
WORKTREE_BASE="${WORKTREE_BASE:-$HOME/source/.worktrees}"
WORKTREE_PARENT="${WORKTREE_BASE}/${REPO_KEY}"

# ── fetch issue ──────────────────────────────
info "Fetching issue #${ISSUE_NUMBER} from GitHub..."

ISSUE_JSON=$(gh issue view "$ISSUE_NUMBER" --json number,title,body,labels,assignees,url 2>/dev/null) ||
  error "Could not fetch issue #${ISSUE_NUMBER}. Are you authenticated with 'gh auth login'?"

ISSUE_TITLE=$(echo "$ISSUE_JSON" | jq -r '.title')
ISSUE_URL=$(echo "$ISSUE_JSON" | jq -r '.url')
ISSUE_LABELS=$(echo "$ISSUE_JSON" | jq -r '[.labels[].name] | join(", ")')
ISSUE_BODY=$(echo "$ISSUE_JSON" | jq -r '.body // "(no description)"')

info "Found: \"${ISSUE_TITLE}\""

# ── branch & worktree ────────────────────────
BRANCH="issue/${ISSUE_NUMBER}"
WORKTREE_PATH="${WORKTREE_PARENT}/issue-${ISSUE_NUMBER}"

mkdir -p "$WORKTREE_PARENT"

info "Syncing latest origin/main..."
git fetch origin main --quiet || error "Could not fetch origin/main."

# Create branch if it doesn't exist
if ! git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  info "Creating branch '${BRANCH}' from origin/main..."
  git branch "$BRANCH" "origin/main"
fi

# Create worktree if it doesn't exist
if [[ -d "$WORKTREE_PATH" ]]; then
  warn "Worktree already exists at ${WORKTREE_PATH} — reusing it."
else
  info "Creating worktree at ${WORKTREE_PATH}..."
  git worktree add "$WORKTREE_PATH" "$BRANCH"
fi

# ── build prompt ─────────────────────────────
PROMPT_FILE="${WORKTREE_PATH}/.issue-prompt.md"

cat >"$PROMPT_FILE" <<PROMPT
# Planning session — Issue #${ISSUE_NUMBER}

## GitHub Issue

**Title:** ${ISSUE_TITLE}
**Labels:** ${ISSUE_LABELS:-none}
**URL:** ${ISSUE_URL}

### Description

${ISSUE_BODY}

---

## Your role

You are a senior developer and planning partner.
I have context on this issue that may go beyond what is written above.

**Interview me until you have 95% confidence about what I actually want — not what I think I should want.**

Ask focused, one-at-a-time questions. When you are confident, produce:

1. **A clear implementation plan** — what to build, what to change, what to leave alone
2. **Acceptance criteria** — how we know it's done
3. **Open questions / risks** — anything that should be decided before touching code
4. **Suggested first step** — the smallest useful thing to do right now

Do not start coding yet. Start by asking your first question.
PROMPT

info "Prompt written to ${PROMPT_FILE}"

if [[ "$NO_LAUNCH" -eq 1 ]]; then
  info "Prepared issue workspace without launching opencode."
  echo "REPO_KEY=${REPO_KEY}"
  echo "WORKTREE_PATH=${WORKTREE_PATH}"
  echo "PROMPT_FILE=${PROMPT_FILE}"
  exit 0
fi

# ── launch opencode ───────────────────────────
info "Switching into worktree and launching opencode..."
echo ""
echo "─────────────────────────────────────────"
echo "  Issue  : #${ISSUE_NUMBER} — ${ISSUE_TITLE}"
echo "  Branch : ${BRANCH}"
echo "  Path   : ${WORKTREE_PATH}"
echo "─────────────────────────────────────────"
echo ""

cd "$WORKTREE_PATH"
exec opencode run "$(cat .issue-prompt.md)"
