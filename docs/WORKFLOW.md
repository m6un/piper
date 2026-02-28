# Piper — Build Workflow

This document is the canonical, agent-agnostic description of how features get
built in this repository. Any agent working here must follow this workflow.
Agent-specific implementations live in their respective config directories
(e.g. `.claude/` for Claude Code) but the workflow itself is defined here.

## Principles
- Humans write intent (spec files). Agents execute.
- No manually-written product code. All product code comes through this loop.
- The workflow is the harness — the better the harness, the faster and safer the output.
- Scripts are bash. Any agent can run bash. Keep it that way.

---

## Triggering a Build
A build is triggered by invoking the build skill with a path to a spec file:

```
/build docs/exec-plans/active/<spec-file>.md
```

The spec file is the human's primary input. See [Spec Format](#spec-format) below.

---

## The Loop

### Setup Phase
1. **Read the spec** — parse feature name, acceptance criteria, scope, out-of-scope
2. **Create an isolated worktree** — all work happens in isolation, main branch is never touched
3. **Parallel init** — Builder and Reviewer both study the codebase before any code is written:
   - Builder reads: `AGENTS.md`, `ARCHITECTURE.md`, `docs/design-docs/core-beliefs.md`, relevant domain doc
   - Reviewer reads: `ARCHITECTURE.md`, `docs/design-docs/core-beliefs.md` — nothing else

### Build Cycle (max 3 cycles)
Each cycle runs four stages in sequence:

#### Stage 1 — BUILD
- Builder addresses previous reviewer findings first (cycle 2+)
- Builder writes tests first (TDD), then implements
- Builder self-reviews against core-beliefs and layer rules before declaring done

#### Stage 2 — VERIFY (inner loop, max 5 retries)
Run: `bash .claude/scripts/run-verify.sh <worktree-path>`

Checks:
- Type-check passes
- Lints pass
- Tests pass

On failure: builder reads output, fixes, retries. After 5 failures → escalate.

#### Stage 3 — PUBLISH
Run: `bash .claude/scripts/publish-pr.sh <worktree-path> <branch> <feature-name> <spec-file>`

Commits changes, pushes branch, creates or updates PR.

#### Stage 4 — REVIEW
Reviewer reads the PR diff via GitHub only (`gh pr diff <pr-number>`).
Cannot touch code. Checks diff against:
- 8 core beliefs (`docs/design-docs/core-beliefs.md`)
- Layer rules (`ARCHITECTURE.md`)
- Test coverage for each acceptance criterion
- Invariants (`AGENTS.md`)

**Output format:**
```
PASS
```
or
```
FAIL
<category>/<severity> <file>:<line> -- <issue> -> <fix>
```
Categories: `architecture` `beliefs` `testing` `invariants`
Severities: `major` `minor`

### Cycle Decision
- PASS → PR is ready for human review
- FAIL → findings written to `<worktree>/.cycle-findings.md`, fed to builder as next cycle input
- 3 cycles exhausted without PASS → escalate

---

## Escalation
Run: `bash .claude/scripts/escalate-pr.sh <pr-number> <findings-file>`

- PR converted to draft
- Labeled `escalated`
- Structured comment posted with last findings, cycle history, and next steps
- Human reviews, clarifies spec or redirects, re-triggers `/build`

---

## Spec Format
See template: `docs/exec-plans/_template.md`

Required fields:
- **What** — one paragraph describing what to build
- **Why** — which core belief or product goal this serves
- **Acceptance criteria** — concrete, testable, checkable by the reviewer
- **Scope** — which domains (backend / ios / both)
- **Out of scope** — explicit list of what the agent must NOT build

---

## Scripts Reference
All scripts live in `.claude/scripts/` and are plain bash.
They work identically in local and remote (cloud VM) environments.

| Script | Purpose |
|--------|---------|
| `create-worktree.sh <branch>` | Creates isolated git worktree at `.worktrees/<branch>` |
| `run-verify.sh <worktree-path>` | Runs type-check, lints, tests. Exits 0 on pass, 1 on fail |
| `publish-pr.sh <worktree> <branch> <name> <spec>` | Commits, pushes, creates/updates PR |
| `escalate-pr.sh <pr-number> <findings-file>` | Converts PR to draft, labels, posts escalation comment |

---

## Agent Implementations
| Agent | Implementation |
|-------|---------------|
| Claude Code | `.claude/skills/build/SKILL.md` |

To add a new agent: implement the workflow above using that agent's native skill/command
format. Point to this document as the source of truth.
