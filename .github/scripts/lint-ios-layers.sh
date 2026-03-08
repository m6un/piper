#!/bin/bash
# Enforces iOS layer rules (ARCHITECTURE.md)
# Views never touch network/storage. Only CookieManager.swift touches App Group.

ERRORS=0
IOS="ios"

# Rule 1: View files must not use URLSession, UserDefaults, or FileManager
while IFS= read -r file; do
  if grep -nE "URLSession|UserDefaults|FileManager" "$file"; then
    echo "FAIL: $(basename "$file") uses network/storage directly — use Services layer"
    ERRORS=$((ERRORS + 1))
  fi
done < <(find "$IOS" -name "*View.swift" 2>/dev/null)

# Rule 2: Only CookieManager.swift may reference UserDefaults or the App Group
# (Test files for CookieManager are excluded — they must verify storage behavior)
while IFS= read -r file; do
  [ "$(basename "$file")" = "CookieManager.swift" ] && continue
  [[ "$(basename "$file")" == *Tests.swift ]] && continue
  if grep -nE "UserDefaults|group\.com\.piper\.app" "$file"; then
    echo "FAIL: $(basename "$file") references App Group cookies — only CookieManager.swift may do this"
    ERRORS=$((ERRORS + 1))
  fi
done < <(find "$IOS" -name "*.swift" 2>/dev/null)

[ $ERRORS -eq 0 ] && echo "PASS: iOS layer rules"
exit $ERRORS
