# Piper — Agent Map

> This is a map, not a manual. Read what's pointed to here.

## What is Piper
A one-tap iOS share extension that extracts authenticated content (e.g. X/Twitter articles) and serves it as a clean, ephemeral HTML page for Instapaper to consume. No accounts. No persistence beyond 1 hour.

## Repo Layout
```
piper/
├── AGENTS.md          ← you are here
├── ARCHITECTURE.md    ← read this second
├── backend/           ← Cloudflare Worker (TypeScript)
├── ios/               ← Xcode project (Swift/SwiftUI)
└── docs/              ← system of record
    ├── design-docs/   ← core beliefs, design decisions
    ├── exec-plans/    ← active and completed plans
    ├── product-specs/ ← what Piper does and why
    ├── BACKEND.md
    ├── IOS.md
    ├── QUALITY_SCORE.md
    ├── RELIABILITY.md
    └── SECURITY.md
```

## Start Here
1. [ARCHITECTURE.md](ARCHITECTURE.md) — system overview, two domains, data flow
2. [docs/design-docs/core-beliefs.md](docs/design-docs/core-beliefs.md) — non-negotiable principles
3. [docs/product-specs/index.md](docs/product-specs/index.md) — what Piper does and for whom
4. Domain docs: [docs/BACKEND.md](docs/BACKEND.md) or [docs/IOS.md](docs/IOS.md)
5. [docs/WORKFLOW.md](docs/WORKFLOW.md) — how features get built (agent-agnostic)
6. [docs/exec-plans/active/](docs/exec-plans/active/) — check for active work before starting

## Invariants (never violate)
- No user accounts. No auth on the backend. Anonymous by design.
- Content TTL is exactly 3600s — enforced at KV write time, never configurable.
- UUID URLs only. Never expose a list or search endpoint.
- Logs contain UUIDs and timestamps only — never content, never source URLs.
- Cookies never reach the backend — on-device only, used for WKWebView auth.
- No reading features. No engagement features. Stay a pipe.

## Workflow
The build workflow is agent-agnostic and fully described in [docs/WORKFLOW.md](docs/WORKFLOW.md).
The Claude Code implementation lives in `.claude/skills/build/`.

- Every change goes through a PR
- Check [docs/exec-plans/active/](docs/exec-plans/active/) for an active plan before starting
- Validate your own changes before opening a PR (lints, build, tests)
- Keep PRs small and focused — one task per PR
- Commit messages: one line, brief and crisp. No bullet points, no body.
