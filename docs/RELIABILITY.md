# Reliability

## Failure Modes

### App
| Failure | User-facing message |
|---------|---------------------|
| Not logged in | "Connect your X account first" |
| No URL on clipboard | "Copy an article URL from X first" |
| Page load fails | "Couldn't load article — check your connection" |
| readability.js returns empty | "Couldn't extract article — try opening in Safari first" |
| Worker POST fails | "Failed to save — please try again" |
| Worker returns non-200 | "Failed to save — please try again" |

### Backend
| Failure | Response |
|---------|----------|
| KV write fails | Return 500 — do not return a partial URL |
| UUID not found / expired | Return 404 with plain text message |
| Malformed POST body | Return 400 with error message |

## Principles
- Fail loudly — never swallow errors silently
- The app must always reach a terminal state (success or failure)
- Never leave the user uncertain about whether the save worked
- No background retries — if it fails, surface it immediately
