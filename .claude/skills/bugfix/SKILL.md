---
description: Run the automated diagnose→fix→verify→publish→review loop for a bug report
invocation: user
---

# /bugfix — Bug Fix Loop

Runs up to 3 full cycles of DIAGNOSE+FIX → VERIFY → PUBLISH → REVIEW.
If all 3 cycles fail reviewer, escalates as a draft PR.

## Usage
/bugfix <path-to-bug-report>
Example: /bugfix docs/exec-plans/active/bug-wkwebview-extraction.md

---

## Step 1 — Read the Bug Report
Read the bug report at $ARGUMENTS. Extract the bug name from the filename
(e.g. `bug-wkwebview-extraction` from `bug-wkwebview-extraction.md`).
Set branch = `bugfix/<bug-name>`.

Write `.build-state.json` to the repo root using real timestamps:
```bash
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > .build-state.json <<EOF
{
  "spec": "$ARGUMENTS",
  "branch": "bugfix/<bug-name>",
  "cycle": 1,
  "started_at": "$NOW",
  "last_updated": "$NOW"
}
EOF
```

---

## Step 2 — Create Worktree
```bash
bash .claude/scripts/create-worktree.sh bugfix/<bug-name>
```
Note the worktree path returned. All work happens inside this path.

---

## Step 3 — Initialization
Spawn the reviewer subagent using .claude/skills/shared/reviewer.md as the prompt.
Pass: paths to docs/design-docs/core-beliefs.md and ARCHITECTURE.md.
Reviewer studies these now, before any code is changed.

Wait for it to complete.

---

## Step 4 — The Loop (max 3 cycles)

Set: cycle = 1, previous_findings = ""

### 4a. DIAGNOSE + FIX
Spawn a bug-fix subagent using .claude/skills/bugfix/bugfix.md as the prompt.
Pass:
- Bug report content (full)
- Worktree path
- Previous reviewer findings: contents of `<worktree-path>/.cycle-findings.md`
  (empty on cycle 1)

Wait for "FIX COMPLETE" before continuing.

### 4b. VERIFY (inner loop, max 5 retries)
```bash
bash .claude/scripts/run-verify.sh <worktree-path>
```

On fail:
  Spawn a bug-fix subagent. Pass it the full failure output.
  Instruct it to fix the failures and confirm when done.
  Re-run verify. Repeat up to 5 times.
  If still failing after 5 retries → skip to Step 6 (Escalation).

On pass → continue to 4c.

### 4c. PUBLISH
```bash
bash .claude/scripts/publish-pr.sh <worktree-path> bugfix/<bug-name> "<bug-name>" "$ARGUMENTS"
```
Note the PR number returned.

### 4d. REVIEW
Spawn a reviewer subagent using .claude/skills/shared/reviewer.md as the prompt.
Pass: PR number, worktree path.

Reviewer runs: `gh pr diff <pr-number>` and evaluates the diff.
Collect the full output.

### 4e. Decision
- Output starts with PASS →
    Go to Step 5.
- Output starts with FAIL →
    Write findings to `<worktree-path>/.cycle-findings.md`
    If cycle < 3:
      Increment cycle. Update `.build-state.json` (cycle and last_updated fields).
      Use `date -u +"%Y-%m-%dT%H:%M:%SZ"` for the new last_updated value.
      Loop back to 4a.
    If cycle == 3: go to Step 6 (Escalation).

---

## Step 5 — Done
Delete `.build-state.json`.
Output: "✅ PR #<n> ready for your review: <pr-url>"
Stop.

---

## Step 6 — Escalation
```bash
bash .claude/scripts/escalate-pr.sh <pr-number> <worktree-path>/.cycle-findings.md
```
Delete `.build-state.json`.
Output: "🚨 Escalated after 3 cycles. Draft PR #<n> needs your input."
Stop.
