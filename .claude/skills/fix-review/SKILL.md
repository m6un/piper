---
description: Read PR review comments, fix the code, verify, and push
invocation: user
---

# /fix-review — Address Review Comments

Reads a PR's review comments, fixes the code in a worktree, verifies, and pushes.

## Usage
```
/fix-review <pr-number>
```

---

## Step 1 — Get PR info

```bash
gh pr view $ARGUMENTS --json headRefName,title,url
```

Extract: `branch` (headRefName), `pr_url`.

---

## Step 2 — Checkout branch into worktree

```bash
git fetch origin <branch>
WORKTREE_PATH=".worktrees/<branch>"
git worktree remove --force "$WORKTREE_PATH" 2>/dev/null || true
git worktree add "$WORKTREE_PATH" "<branch>"
```

This tracks the *existing* branch — do not create a new branch from HEAD.

---

## Step 3 — Spawn fixer agent

Read `.claude/skills/fix-review/fixer.md` and use it as the prompt.
Pass:
- PR number: `$ARGUMENTS`
- Worktree path

Wait for "FIX COMPLETE — <summary>" before continuing.
Capture the summary text (everything after "FIX COMPLETE — ").

---

## Step 4 — Verify (inner loop, max 5 retries)

```bash
bash .claude/scripts/run-verify.sh <worktree-path>
```

On fail:
  Spawn a fixer subagent with the full failure output.
  Instruct it to fix only the verification failures and confirm when done.
  Re-run verify. Repeat up to 5 times.
  After 5 fails: comment on the PR explaining what couldn't be fixed, then stop.

```bash
gh pr comment $ARGUMENTS --body "fix-review: verification failed after 5 retries.

Failures:
<failure-output>

Manual intervention needed."
```

On pass → continue to Step 5.

---

## Step 5 — Push

Inside the worktree:

```bash
cd <worktree-path>

# Commit if there are changes
if ! git diff --quiet || ! git diff --cached --quiet; then
  git add -A
  git commit -m "fix: address review comments"
fi

# Push (covers both new commits and the case where fixer already committed)
git push
```

---

## Step 6 — Comment on PR

```bash
gh pr comment $ARGUMENTS --body "fix-review: addressed review comments.

<fixer-summary>"
```

Output: "✅ Review comments addressed on PR #<n>: <pr_url>"
