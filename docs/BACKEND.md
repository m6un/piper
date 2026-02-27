# Backend Domain

## Overview
A minimal Cloudflare Worker that acts as a short-lived content store. Stateless, anonymous, no auth.

## Stack
- **Runtime**: Cloudflare Workers (TypeScript, strict mode)
- **Storage**: Cloudflare KV
- **Tooling**: Wrangler v3

## Endpoints

### `POST /save`
Accepts `{ title: string, content: string }`. Validates both fields are present. Generates a UUID, stores `{ title, content, savedAt }` in KV with `expirationTtl: 3600`. Returns `{ url: string }` where url is `https://{worker-domain}/{uuid}`.

### `GET /{uuid}`
Looks up the UUID in KV. Returns 404 if not found or expired. Returns a clean, minimal HTML page with the article title and content if found.

## Layer Structure
```
src/
├── index.ts        ← router only, no business logic
├── handlers/
│   ├── save.ts     ← POST /save
│   └── get.ts      ← GET /{uuid}
└── store.ts        ← KV read/write, single source of truth for storage
```

## Constraints
- Never log content or source URLs — UUID + timestamp only
- TTL is hardcoded at 3600 — not an env var, not configurable
- No auth, no rate limiting in v1 (UUID entropy is the security model)
- CORS open for iOS requests

## Local Dev
```bash
cd backend
npm install
npm run dev   # wrangler dev
```
