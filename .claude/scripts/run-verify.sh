#!/bin/bash
# Runs all available checks for the repo domains.
# Exits 0 on full pass, 1 on any failure.
# Output is the failure detail — builder reads this to fix.

WORKTREE_PATH=$1

if [ -z "$WORKTREE_PATH" ]; then
  echo "Usage: run-verify.sh <worktree-path>" >&2
  exit 1
fi

cd "$WORKTREE_PATH"

FAILED=0

# ── Backend (Cloudflare Worker / TypeScript) ─────────────────────────────────
if [ -d "backend" ]; then
  echo "▶ backend: type-check"
  (cd backend && npm run type-check 2>&1) || { echo "✗ backend:type-check failed"; FAILED=1; }

  echo "▶ backend: lint"
  (cd backend && npm run lint 2>&1) || { echo "✗ backend:lint failed"; FAILED=1; }

  echo "▶ backend: test"
  (cd backend && npm test 2>&1) || { echo "✗ backend:test failed"; FAILED=1; }

  echo "▶ backend: layer rules"
  bash .github/scripts/lint-backend-layers.sh 2>&1 || { echo "✗ backend:layer-rules failed"; FAILED=1; }
fi

# ── iOS (Swift) ──────────────────────────────────────────────────────────────
# Note: xcodebuild not available on cloud VMs — swiftlint only for now.
# Full build/test requires a macOS runner or local execution.
if [ -d "ios" ]; then
  echo "▶ ios: layer rules"
  bash .github/scripts/lint-ios-layers.sh 2>&1 || { echo "✗ ios:layer-rules failed"; FAILED=1; }

  if command -v swiftlint &>/dev/null; then
    echo "▶ ios: swiftlint"
    swiftlint --path ios 2>&1 || { echo "✗ ios:swiftlint failed"; FAILED=1; }
  else
    echo "⚠ ios: swiftlint not found, skipping"
  fi
fi

# ── Result ────────────────────────────────────────────────────────────────────
if [ "$FAILED" -eq 1 ]; then
  echo ""
  echo "FAIL — fix the errors above and re-run"
  exit 1
fi

echo ""
echo "PASS"
exit 0
