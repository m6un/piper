# Piper — Architecture

## System Overview
```
[X App] → Share Sheet → [iOS Share Extension]
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
- **Main App**: SwiftUI — explains product, handles X login via WKWebView, persists cookies to App Group
- **Share Extension**: Receives URL, loads page with stored cookies, injects readability.js, extracts content, POSTs to worker, copies temp URL to clipboard
- **Cookie Bridge**: `group.com.piper.app` App Group — the only shared state between app and extension
- **Stack**: Swift, SwiftUI, WKWebView
- See [docs/IOS.md](docs/IOS.md)

## Data Flow
1. User logs into X in main app → cookies saved to App Group
2. User shares article URL from X → Share Extension activates
3. Extension loads URL in WKWebView using stored cookies (authenticated)
4. readability.js injected → extracts `{title, content}`
5. Content POSTed to worker → stored under random UUID in KV (TTL 3600s)
6. UUID URL returned → copied to clipboard
7. User pastes URL into Instapaper → Instapaper fetches `GET /{uuid}`
8. Worker serves clean HTML → content expires after 1 hour

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
CookieManager (cross-cutting, App Group boundary)
```
- Views never touch network or storage directly
- CookieManager is the sole read/write point for cookies
- Share Extension shares no view-layer code with the main app

## Key Constraints
- Backend is stateless and anonymous — no request logging beyond UUID + timestamp
- The worker has no knowledge of source URL, user, or platform
- Cookie sharing is one-way: main app writes, extension reads
