#!/bin/bash
# Checks that all relative .md links in markdown files resolve to actual files.

ERRORS=0
ROOT="$(git rev-parse --show-toplevel)"

while IFS= read -r mdfile; do
  dir="$(dirname "$mdfile")"
  while IFS= read -r link; do
    # Skip external links and anchors
    [[ "$link" == http* ]] && continue
    [[ "$link" == "#"* ]] && continue
    # Only check links to .md files
    [[ "$link" != *.md* ]] && continue
    # Strip anchor
    path="${link%%#*}"
    [ -z "$path" ] && continue
    target="$dir/$path"
    if [ ! -f "$target" ]; then
      echo "DEAD LINK in $mdfile: $link"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(grep -oP '(?<=\]\()[^)]+' "$mdfile" 2>/dev/null || true)
done < <(find "$ROOT" -name "*.md" ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/.worktrees/*")

[ $ERRORS -eq 0 ] && echo "PASS: all doc links resolve"
exit $ERRORS
