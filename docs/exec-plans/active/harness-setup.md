# Harness Setup

This is the active execution plan for setting up the Piper agent harness.
Not a product feature — this is the infrastructure that enables agent-driven development.

## Status: In Progress

---

## Phase 1 — Repository Foundation
- [x] Global `~/.claude/CLAUDE.md` — user preferences and workflow rules
- [x] `CLAUDE.md` (repo root) — sources AGENTS.md
- [x] `AGENTS.md` — repo map, invariants, workflow pointer
- [x] `ARCHITECTURE.md` — two domains, data flow, layer rules
- [x] `docs/design-docs/core-beliefs.md` — 8 product beliefs
- [x] `docs/product-specs/index.md` — product spec
- [x] `docs/BACKEND.md`, `docs/IOS.md` — domain docs
- [x] `docs/SECURITY.md`, `docs/RELIABILITY.md`, `docs/QUALITY_SCORE.md`
- [x] `docs/WORKFLOW.md` — agent-agnostic build workflow (source of truth)
- [x] `docs/PLANS.md`, `docs/exec-plans/` structure
- [x] `.gitignore`

## Phase 2 — Build Loop (Ralph Wiggum)
- [x] `.claude/skills/build/SKILL.md` — `/build` entry point
- [x] `.claude/skills/build/builder.md` — builder agent prompt
- [x] `.claude/skills/build/reviewer.md` — reviewer agent prompt (checks CI)
- [x] `.claude/scripts/create-worktree.sh`
- [x] `.claude/scripts/run-verify.sh`
- [x] `.claude/scripts/publish-pr.sh`
- [x] `.claude/scripts/escalate-pr.sh`
- [x] `docs/exec-plans/_template.md` — spec template for human input

## Phase 3 — Quota Recovery
- [x] `.claude/scripts/resume-build.sh` — two-signal safeguard, re-triggers via `claude --remote`
- [x] `docs/vps-setup.md` — VPS + Mac runner setup instructions
- [x] `.github/workflows/ios-verify.yml` — iOS CI on self-hosted Mac runner

## Phase 4 — Git & Remote (next up)
- [ ] Commit pending changes (scripts, SKILL.md updates, ios-verify.yml, vps-setup.md)
- [ ] Create GitHub remote repo
- [ ] Push all commits
- [ ] Install Claude GitHub App (`/install-github-app` in Claude Code)

## Phase 5 — Infrastructure Setup
- [ ] Mac: register self-hosted GitHub Actions runner (label: `self-hosted,macos,piper`)
- [ ] VPS: install Claude Code, authenticate, clone repo
- [ ] VPS: set `PIPER_REPO_DIR` env var
- [ ] VPS: replace `{owner}/{repo}` placeholder in `resume-build.sh`
- [ ] VPS: register crontab entry (`0 * * * *`)
- [ ] Verify end-to-end: cron dry-run, runner shows online in GitHub

## Phase 6 — Enforcement & Linting
- [ ] Custom linter: enforce backend layer rules (Router → Handlers → store.ts)
- [ ] Custom linter: enforce iOS layer rules (Views never touch network/storage)
- [ ] CI job: validate docs freshness (cross-links, stale content)
- [ ] Architecture constraint tests

## Phase 7 — Doc Gardening Agent
- [ ] Scheduled agent that scans for stale docs vs actual code
- [ ] Opens fix PRs automatically
- [ ] Runs on a cron (GitHub Actions scheduled workflow)

## Phase 8 — Advanced Tooling (post-MVP)
- [ ] CDP wiring — skills for DOM snapshots, screenshots, navigation
- [ ] Observability stack — ephemeral logs/metrics/traces per worktree (LogQL, PromQL)
- [ ] App bootable per worktree — isolated instance per agent task

---

## Notes
- Phases 1–3 are complete and committed (except the pending Phase 4 commit)
- Phases 4–6 must be completed before any product code is written
- Phase 7 (doc gardening) deferred until agents have written meaningful code and docs start drifting
- Phase 8 (CDP, observability) deferred post-MVP
- The harness is usable after Phase 6 is complete
