#!/bin/bash
# Enforces backend layer rules (ARCHITECTURE.md)
# Router (index.ts) → Handlers → store.ts only

ERRORS=0
BACKEND="backend/src"

# Rule 1: index.ts must not import store.ts directly
if [ -f "$BACKEND/index.ts" ] && grep -nE "from ['\"].*store['\"]" "$BACKEND/index.ts"; then
  echo "FAIL: index.ts imports store.ts directly — route through handlers"
  ERRORS=$((ERRORS + 1))
fi

# Rule 2: handlers must not access KV directly (use store.ts)
while IFS= read -r file; do
  if grep -nE "env\.[A-Za-z_]+\.(get|put|delete|list)\(" "$file"; then
    echo "FAIL: $(basename "$file") accesses KV directly — use store.ts"
    ERRORS=$((ERRORS + 1))
  fi
done < <(find "$BACKEND/handlers" -name "*.ts" 2>/dev/null)

[ $ERRORS -eq 0 ] && echo "PASS: backend layer rules"
exit $ERRORS
