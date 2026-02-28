#!/bin/bash
# Converts the PR to draft, labels it escalated, and posts a structured comment
# with the last reviewer findings so the human knows exactly where it got stuck.

set -e

PR_NUMBER=$1
FINDINGS_FILE=$2

if [ -z "$PR_NUMBER" ] || [ -z "$FINDINGS_FILE" ]; then
  echo "Usage: escalate-pr.sh <pr-number> <findings-file>" >&2
  exit 1
fi

FINDINGS=$(cat "$FINDINGS_FILE" 2>/dev/null || echo "No findings file found at $FINDINGS_FILE")

# Convert to draft
gh pr ready "$PR_NUMBER" --undo 2>/dev/null || true

# Create the escalated label if it doesn't exist
gh label create "escalated" --color "E11D48" --description "Loop exhausted — needs human input" 2>/dev/null || true
gh pr edit "$PR_NUMBER" --add-label "escalated"

# Post escalation comment
gh pr comment "$PR_NUMBER" --body "$(cat <<EOF
🚨 **Escalated after 3 cycles — needs human input**

The build loop exhausted all retry attempts without passing review.

**Last reviewer findings:**
\`\`\`
$FINDINGS
\`\`\`

**Next steps:**
1. Review the findings above
2. Update the spec at the path listed in the PR description, or leave a comment clarifying intent
3. Re-run \`/build\` with the updated spec to start a new loop
EOF
)"

echo "$PR_NUMBER"
