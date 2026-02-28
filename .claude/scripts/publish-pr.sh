#!/bin/bash
# Commits changes in the worktree, pushes the branch, and creates or updates a PR.
# Prints the PR number on success.

set -e

WORKTREE_PATH=$1
BRANCH=$2
FEATURE_NAME=$3
SPEC_FILE=$4

if [ -z "$WORKTREE_PATH" ] || [ -z "$BRANCH" ] || [ -z "$FEATURE_NAME" ] || [ -z "$SPEC_FILE" ]; then
  echo "Usage: publish-pr.sh <worktree-path> <branch> <feature-name> <spec-file>" >&2
  exit 1
fi

cd "$WORKTREE_PATH"

# Nothing to commit — bail early
if git diff --quiet && git diff --cached --quiet; then
  echo "Nothing to commit in worktree $WORKTREE_PATH" >&2
  exit 1
fi

git add -A
git commit -m "feat: $FEATURE_NAME

Built by agent — spec: $SPEC_FILE"

git push -u origin "$BRANCH"

# Create PR if one doesn't exist for this branch, otherwise just push
EXISTING_PR=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number' 2>/dev/null || echo "")

if [ -z "$EXISTING_PR" ]; then
  SPEC_CONTENT=$(cat "../$SPEC_FILE" 2>/dev/null || echo "See $SPEC_FILE")

  PR_NUMBER=$(gh pr create \
    --title "feat: $FEATURE_NAME" \
    --body "$(cat <<EOF
## Summary
Built by agent per spec: \`$SPEC_FILE\`

## Spec
$SPEC_CONTENT

EOF
)" \
    --head "$BRANCH" \
    --json number \
    --jq '.number')

  echo "$PR_NUMBER"
else
  echo "$EXISTING_PR"
fi
