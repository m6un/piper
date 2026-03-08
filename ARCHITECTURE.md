# Piper — Architecture

## System Overview
```
[X App] → copy URL → [Piper iOS App]
                          ↓ load URL with cookies → readability.js
                          ↓ POST /save {title, content}
                   [Cloudflare Worker + KV]
                          ↓ returns {url}
          clipboard ← uuid temp url
                          ↓ paste into Instapaper
                   GET /{uuid} → clean HTML (expires 1hr)
```

## Domains

### Backend (`backend/`)
- **Runtime**: Cloudflare Worker (TypeScript)
- **Storage**: Cloudflare KV — TTL 3600s, no extensions
- **Endpoints**:
  - `POST /save` — accepts `{title, content}`, stores under random UUID, returns `{url}`
  - `GET /{uuid}` — serves stored content as clean HTML; 404 if expired
- **Stack**: TypeScript strict, Wrangler v3
- See [docs/BACKEND.md](docs/BACKEND.md)

### iOS (`ios/`)
- **Single App**: SwiftUI — handles X login via WKWebView, persists cookies locally, extracts content from pasted URLs, POSTs to backend, copies result URL to clipboard
- **Stack**: Swift, SwiftUI, WKWebView, readability.js
- See [docs/IOS.md](docs/IOS.md)

## Data Flow
1. User logs into X in app → cookies saved to UserDefaults
2. User copies article URL from X app
3. User opens Piper → app reads URL from clipboard
4. Hidden WKWebView loads URL using stored cookies (authenticated)
5. readability.js injected → extracts `{title, content}`
6. Content POSTed to worker → stored under random UUID in KV (TTL 3600s)
7. UUID URL returned → copied to clipboard
8. User pastes URL into Instapaper → Instapaper fetches `GET /{uuid}`
9. Worker serves clean HTML → content expires after 1 hour

## Layer Rules

### Backend
```
Router (index.ts) → Handlers → KV Store
```
- Router does routing only — no business logic
- Handlers own request validation and response shaping
- KV access goes through `store.ts` only — not directly from handlers

### iOS
```
Models → Services → Views
CookieManager (cross-cutting, local storage boundary)
```
- Views never touch network or storage directly
- CookieManager is the sole read/write point for cookies
- Services (ContentExtractor, PiperAPIClient, PipelineController) own all logic

## Key Constraints
- Backend is stateless and anonymous — no request logging beyond UUID + timestamp
- The worker has no knowledge of source URL, user, or platform
- Cookies never leave the device — stored locally, used only for WKWebView requests
