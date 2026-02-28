---
description: Run the automated build→verify→publish→review loop for a feature spec
invocation: user
---

# /build — Ralph Wiggum Loop

This is the Claude Code implementation of the build workflow.
Canonical workflow definition (agent-agnostic): docs/WORKFLOW.md

Runs up to 3 full cycles of BUILD → VERIFY → PUBLISH → REVIEW.
If all 3 cycles fail reviewer, escalates as a draft PR.

## Usage
/build <path-to-spec-file>
Example: /build docs/exec-plans/active/add-x-login.md

---

## Step 1 — Read the Spec
Read the spec file at $ARGUMENTS. Extract the feature name from the filename
(e.g. `add-x-login` from `add-x-login.md`). Set branch = `agent/<feature-name>`.

Write `.build-state.json` to the repo root:
```json
{
  "spec": "<$ARGUMENTS>",
  "branch": "agent/<feature-name>",
  "cycle": 1,
  "started_at": "<iso-timestamp>",
  "last_updated": "<iso-timestamp>"
}
```

---

## Step 2 — Create Worktree
```bash
bash .claude/scripts/create-worktree.sh agent/<feature-name>
```
Note the worktree path returned. All build work happens inside this path.

---

## Step 3 — Parallel Initialization
Spawn two subagents in parallel using the Task tool:

**Builder Init:**
Read the contents of .claude/skills/build/builder.md and use it as the prompt.
Pass: spec content, worktree path, previous_findings = "".

**Reviewer Init:**
Read the contents of .claude/skills/build/reviewer.md and use it as the prompt.
Pass: paths to docs/design-docs/core-beliefs.md and ARCHITECTURE.md.
Reviewer studies these now, before any code exists.

Wait for both to complete.

---

## Step 4 — The Loop (max 3 cycles)

Set: cycle = 1, previous_findings = ""

### 4a. BUILD
Spawn a builder subagent using .claude/skills/build/builder.md as the prompt.
Pass:
- Spec content (full)
- Worktree path
- Previous reviewer findings: contents of `<worktree-path>/.cycle-findings.md`
  (empty on cycle 1)

Wait for "BUILD COMPLETE" before continuing.

### 4b. VERIFY (inner loop, max 5 retries)
```bash
bash .claude/scripts/run-verify.sh <worktree-path>
```

On fail:
  Spawn a builder subagent. Pass it the full failure output.
  Instruct it to fix the failures and confirm when done.
  Re-run verify. Repeat up to 5 times.
  If still failing after 5 retries → skip to Step 6 (Escalation).

On pass → continue to 4c.

### 4c. PUBLISH
```bash
bash .claude/scripts/publish-pr.sh <worktree-path> agent/<feature-name> "<feature-name>" "$ARGUMENTS"
```
Note the PR number returned.

### 4d. REVIEW
Spawn a reviewer subagent using .claude/skills/build/reviewer.md as the prompt.
Pass: PR number, worktree path.

Reviewer runs: `gh pr diff <pr-number>` and evaluates the diff.
Collect the full output.

### 4e. Decision
- Output starts with PASS →
    Go to Step 5.
- Output starts with FAIL →
    Write findings to `<worktree-path>/.cycle-findings.md`
    If cycle < 3:
      Increment cycle. Update `.build-state.json` (cycle and last_updated).
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
