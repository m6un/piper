# Security

## Principles
- No user data stored beyond article content under a UUID
- Content expires in 3600s — enforced at write time, never configurable
- Cookies stay on-device, used only for WKWebView authenticated requests
- Backend logs: UUID and timestamp only — never content, source URL, or IP

## Threat Model

**What we protect against:**
- **Content enumeration**: UUID v4 (122 bits entropy) makes guessing infeasible. 1hr TTL limits any exposure window.
- **Cookie leakage**: Cookies are never transmitted to the backend. Stored in standard UserDefaults on-device — sufficient for this threat model.
- **Subpoena**: Logs contain nothing attributable to a user or their reading habits.

**What we accept:**
- The UUID URL is technically public. Anyone with the URL can fetch the content within the 1hr window. UUID entropy + short TTL is the privacy model — this is acceptable.
- No rate limiting on `POST /save` in v1. Low abuse risk given anonymous design and short TTL.

## Rules
- Never add a `GET /list` or `GET /search` endpoint
- Never log request bodies or response content on the backend
- Never add server-side user identifiers of any kind
- Never extend TTL, make it configurable, or add a "renew" endpoint
