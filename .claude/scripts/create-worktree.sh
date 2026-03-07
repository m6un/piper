#!/bin/bash
set -e

BRANCH=$1
BASE_REF=${2:-HEAD}

if [ -z "$BRANCH" ]; then
  echo "Usage: create-worktree.sh <branch-name> [base-ref]" >&2
  exit 1
fi

WORKTREE_PATH=".worktrees/$BRANCH"

# Clean up existing worktree for this branch if it exists
if [ -d "$WORKTREE_PATH" ]; then
  git worktree remove --force "$WORKTREE_PATH" 2>/dev/null || true
  git branch -D "$BRANCH" 2>/dev/null || true
fi

# Create new worktree on a fresh branch from base ref (default: HEAD)
git fetch origin --quiet 2>/dev/null || true
git worktree add -b "$BRANCH" "$WORKTREE_PATH" "$BASE_REF"

echo "$WORKTREE_PATH"
