#!/bin/bash
set -e

ISSUE_NUMBER=$1
STATUS=${2:-"In Progress"} # default to "In Progress", but overridable

# Get owner and repo from git remote
REMOTE_URL=$(git remote get-url origin)
REPO=$(echo "$REMOTE_URL" | sed 's/.*[:/]\([^/]*\/[^/]*\)\.git$/\1/' | sed 's/.*[:/]\([^/]*\/[^/]*\)$/\1/')
OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)

echo "Owner: $OWNER / Repo: $REPO_NAME"

PROJECTS=$(gh project list --owner "$OWNER" --format json)
# Find the project number linked to this repo
PROJECT_NUMBER=$(echo $PROJECTS | jq -r ".projects[] | select(.url | contains(\"$OWNER\")) | .number" | head -1)

echo "Project: $PROJECT_NUMBER"

# Get the global project node ID
PROJECT_ID=$(echo $PROJECTS | jq -r ".projects[] | select(.number == $PROJECT_NUMBER) | .id")

echo "Project ID: $PROJECT_ID"

# Get field + option IDs
FIELDS_JSON=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json)

FIELD_ID=$(echo "$FIELDS_JSON" | jq -r '.fields[] | select(.name == "Status") | .id')
OPTION_ID=$(echo "$FIELDS_JSON" | jq -r --arg status "$STATUS" \
  '.fields[] | select(.name == "Status") | .options[] | select(.name == $status) | .id')

echo "Field ID: $FIELD_ID"
echo "Option ID: $OPTION_ID"

# Find the project item ID for this issue
ITEM_ID=$(gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --format json |
  jq -r ".items[] | select(.content.number == $ISSUE_NUMBER) | .id")

echo "Item ID: $ITEM_ID"

# Update the status
gh project item-edit \
  --project-id "$PROJECT_ID" \
  --id "$ITEM_ID" \
  --field-id "$FIELD_ID" \
  --single-select-option-id "$OPTION_ID"

echo "✓ Issue #$ISSUE_NUMBER moved to '$STATUS'"
