# Feature Spec: backend-worker

## What
Build the Cloudflare Worker that acts as Piper's content bridge. Two endpoints: `POST /save` stores article content under a random UUID with a 1-hour TTL and returns the URL; `GET /{uuid}` serves that content as clean HTML or 404 if expired.

## Why
Belief #2 — Ephemeral by design. Belief #3 — Stay a pipe. The backend is the pipe: anonymous, stateless, and self-expiring. Nothing gets built on iOS until this exists and is deployed.

## Acceptance Criteria
- [ ] `POST /save` with `{ title, content }` returns `{ url }` where url contains a UUID path
- [ ] `POST /save` with missing `title` or `content` returns 400
- [ ] `GET /{uuid}` returns a clean HTML page containing the title and content
- [ ] `GET /{uuid}` for an unknown or expired UUID returns 404
- [ ] KV write uses `expirationTtl: 3600` — hardcoded, not an env var
- [ ] `index.ts` contains routing only — no business logic
- [ ] All KV access goes through `store.ts` — not called directly from handlers
- [ ] Layer linter (`lint-backend-layers.sh`) passes
- [ ] All acceptance criteria covered by tests
- [ ] `npm run type-check` and `npm run lint` pass

## Scope
- **Domains**: backend only
- **Files likely touched**:
  - `backend/src/index.ts`
  - `backend/src/handlers/save.ts`
  - `backend/src/handlers/get.ts`
  - `backend/src/store.ts`
  - `backend/wrangler.toml`
  - `backend/package.json`
  - `backend/tsconfig.json`
  - `backend/src/index.test.ts` (or equivalent test files)

## Out of Scope
- Deployment to Cloudflare (wrangler deploy) — local dev and tests only
- Rate limiting
- CORS configuration beyond allowing iOS requests
- Any endpoint beyond POST /save and GET /{uuid}
- Any logging beyond UUID + timestamp
- Auth of any kind

## Notes
- UUID generation: use `crypto.randomUUID()` — available natively in Cloudflare Workers
- The returned URL format: `https://{worker-domain}/{uuid}` — use a placeholder domain in tests (e.g. `https://piper.workers.dev/{uuid}`)
- KV binding name in wrangler.toml: `CONTENT_STORE`
- See ARCHITECTURE.md and docs/BACKEND.md for layer rules and constraints
