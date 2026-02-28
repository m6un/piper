#!/bin/bash
# Runs on the VPS via cron every hour.
# If a build was interrupted (quota exhaustion, crash, etc.), re-triggers it.
# If quota is still exhausted, claude --remote will fail — cron retries next hour.
#
# Safeguard logic (both signals must be stale before re-triggering):
#   Primary:   no commits on the branch in the last 2 hours (GitHub as source of truth)
#   Secondary: state file last_updated older than 2 hours (covers the BUILD phase
#              where code is being written but not yet committed)

set -e

REPO_DIR="${PIPER_REPO_DIR:-$HOME/piper}"
STATE_FILE="$REPO_DIR/.build-state.json"
TWO_HOURS=7200

cd "$REPO_DIR" || { echo "Repo not found at $REPO_DIR"; exit 1; }

git pull --quiet

# No interrupted build — nothing to do
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

NOW_EPOCH=$(date +%s)
SPEC=$(jq -r '.spec' "$STATE_FILE")
BRANCH=$(jq -r '.branch' "$STATE_FILE")
CYCLE=$(jq -r '.cycle' "$STATE_FILE")

# ── Primary signal: GitHub branch commit activity ─────────────────────────────
LAST_COMMIT=$(gh api "repos/{owner}/{repo}/branches/$BRANCH" \
  --jq '.commit.commit.author.date' 2>/dev/null || echo "")

if [ -n "$LAST_COMMIT" ]; then
  LAST_COMMIT_EPOCH=$(date -d "$LAST_COMMIT" +%s 2>/dev/null || echo 0)
  COMMIT_DIFF=$(( NOW_EPOCH - LAST_COMMIT_EPOCH ))

  if [ "$COMMIT_DIFF" -lt $TWO_HOURS ]; then
    echo "Branch had a commit $(( COMMIT_DIFF / 60 ))m ago — build likely running, skipping"
    exit 0
  fi
fi

# ── Secondary signal: state file timestamp ────────────────────────────────────
# Covers the BUILD phase where code is being written but not yet committed.
LAST_UPDATED=$(jq -r '.last_updated' "$STATE_FILE")
LAST_UPDATED_EPOCH=$(date -d "$LAST_UPDATED" +%s 2>/dev/null || echo 0)
STATE_DIFF=$(( NOW_EPOCH - LAST_UPDATED_EPOCH ))

if [ "$STATE_DIFF" -lt $TWO_HOURS ]; then
  echo "State file updated $(( STATE_DIFF / 60 ))m ago — build may be in progress, skipping"
  exit 0
fi

# ── Both signals stale — build is dead, re-trigger ───────────────────────────
echo "Interrupted build detected (spec: $SPEC, branch: $BRANCH, last cycle: $CYCLE)"
echo "Last commit: $(( COMMIT_DIFF / 60 ))m ago, state file: $(( STATE_DIFF / 60 ))m ago"
echo "Re-triggering via claude --remote..."

claude --remote "/build $SPEC"
