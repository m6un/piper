#!/bin/bash
# Runs all available checks for the repo domains.
# Exits 0 on full pass, 1 on any failure.
# Output is the failure detail — builder reads this to fix.

WORKTREE_PATH=$1

if [ -z "$WORKTREE_PATH" ]; then
  echo "Usage: run-verify.sh <worktree-path>" >&2
  exit 1
fi

if [ ! -d "$WORKTREE_PATH" ]; then
  echo "ERROR: worktree path does not exist: $WORKTREE_PATH" >&2
  exit 1
fi

cd "$WORKTREE_PATH"

FAILED=0

# ── Backend (Cloudflare Worker / TypeScript) ─────────────────────────────────
if [ -d "backend" ]; then
  echo "▶ backend: install dependencies"
  (cd backend && npm install --silent 2>&1) || { echo "✗ backend:npm-install failed"; FAILED=1; }

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
if [ -d "ios" ]; then
  echo "▶ ios: layer rules"
  bash .github/scripts/lint-ios-layers.sh 2>&1 || { echo "✗ ios:layer-rules failed"; FAILED=1; }

  if command -v swiftlint &>/dev/null; then
    echo "▶ ios: swiftlint"
    swiftlint --path ios 2>&1 || { echo "✗ ios:swiftlint failed"; FAILED=1; }
  else
    echo "⚠ ios: swiftlint not found, skipping"
  fi

  # xcodebuild: only available on macOS with Xcode installed.
  # On VPS (Linux) this step is skipped automatically.
  if command -v xcodebuild &>/dev/null; then
    XCODE_PROJECT="ios/Piper/Piper.xcodeproj"
    # Pick the first available iPhone simulator (name only for reliable matching).
    SIM_NAME=$(xcodebuild -project "$XCODE_PROJECT" -scheme Piper \
      -showdestinations 2>/dev/null \
      | grep 'platform:iOS Simulator.*iPhone' \
      | head -1 \
      | sed 's/.*name://' | sed 's/ }.*//') || true
    SIM_DEST="${SIM_NAME:+platform=iOS Simulator,name=$SIM_NAME}"

    if [ -n "$SIM_DEST" ]; then
      echo "▶ ios: xcodebuild build (${SIM_DEST})"
      xcodebuild build -project "$XCODE_PROJECT" -scheme Piper \
        -destination "$SIM_DEST" -quiet 2>&1 \
        || { echo "✗ ios:xcodebuild-build failed"; FAILED=1; }

      echo "▶ ios: xcodebuild test"
      xcodebuild test -project "$XCODE_PROJECT" -scheme Piper \
        -destination "$SIM_DEST" -quiet 2>&1 \
        || { echo "✗ ios:xcodebuild-test failed"; FAILED=1; }
    else
      echo "⚠ ios: no iPhone simulator found, skipping xcodebuild"
    fi
  else
    echo "⚠ ios: xcodebuild not found (not macOS?), skipping build/test"
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
