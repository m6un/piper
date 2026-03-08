# Feature Spec: ios-share-extension

## What
Build Piper's share extension: receives a URL from the iOS share sheet, loads it in
a hidden WKWebView with injected X cookies, extracts clean article content using
readability.js, POSTs {title, content} to the backend /save endpoint, copies the
returned URL to clipboard, and shows success/error confirmation.

## Why
Belief #4 — The share extension IS the product. Belief #6 — Fail loudly on every
error. Belief #7 — Content fidelity over speed.

## Acceptance Criteria
- [ ] Extension appears in the iOS share sheet for URLs
- [ ] On activation, reads cookies from App Group via CookieManager
- [ ] If no cookies found, shows error: "Open Piper to connect your X account"
- [ ] Loads the shared URL in a hidden WKWebView with injected cookies
- [ ] Injects readability.js and extracts {title, content}
- [ ] If extraction fails, shows error to user — no silent failure
- [ ] POSTs extracted {title, content} to backend /save endpoint
- [ ] On success, copies returned UUID URL to clipboard
- [ ] Shows confirmation: "Saved — paste into Instapaper"
- [ ] On network/backend failure, shows error with reason
- [ ] Backend URL is a single constant, not hardcoded in multiple places
- [ ] readability.js is bundled as a resource in the extension target
- [ ] Views never access network or storage directly
- [ ] Share extension shares no view-layer code with the main app
- [ ] Layer linter (lint-ios-layers.sh) passes

## Test Cases

### PiperAPIClient Tests (ios/PiperShareExtensionTests/PiperAPIClientTests.swift)

| # | Test | Input | Expected Output |
|---|------|-------|-----------------|
| 1 | Successful save | Mock 200 response with `{"url":"https://piper.workers.dev/abc-123"}` | Returns the URL string |
| 2 | Server error | Mock 500 response | Throws/returns error with "Failed to save" |
| 3 | Invalid JSON response | Mock 200 with malformed body | Throws/returns parse error |
| 4 | Network timeout | Mock timeout | Throws/returns timeout error |
| 5 | 400 bad request | Mock 400 response | Throws/returns error with server message |
| 6 | Request body format | Call save(title:content:) | Request body is JSON `{"title":"...","content":"..."}` |
| 7 | Backend URL is Config constant | Inspect request URL | URL starts with Config.backendBaseURL |

### ContentExtractor Tests (ios/PiperShareExtensionTests/ContentExtractorTests.swift)

| # | Test | Input | Expected Output |
|---|------|-------|-----------------|
| 1 | Extracts title and content | readability.js returns `{title:"Test",content:"<p>Hello</p>"}` | ExtractedContent with matching title and content |
| 2 | Handles empty title | readability.js returns `{title:"",content:"<p>Body</p>"}` | Returns content with empty title (or fallback) |
| 3 | Handles null result | readability.js returns null (not an article) | Throws extraction error |
| 4 | Handles JS execution error | evaluateJavaScript fails | Throws extraction error, doesn't crash |

### ShareViewController Integration Tests (ios/PiperShareExtensionTests/ShareViewControllerTests.swift)

| # | Test | Input | Expected Output |
|---|------|-------|-----------------|
| 1 | No cookies — shows error | CookieManager returns empty | Error UI shown: "Open Piper to connect your X account" |
| 2 | No URL in share input | Extension context has no URL | Error UI shown |
| 3 | Full happy path | Valid cookies + mock page + mock API success | Success UI: "Saved — paste into Instapaper" |
| 4 | Extraction failure path | Valid cookies + page that fails readability | Error UI: extraction failure message |
| 5 | Network failure path | Valid cookies + extraction succeeds + API fails | Error UI with network reason |

### Config Tests (ios/PiperShareExtensionTests/ConfigTests.swift)

| # | Test | Input | Expected Output |
|---|------|-------|-----------------|
| 1 | Backend URL is valid | Config.backendBaseURL | Is a valid URL, starts with https:// |
| 2 | Backend URL has no trailing slash | Config.backendBaseURL | Does not end with "/" |

## Scope
- **Domains**: ios only
- **Files likely touched**:
  - ios/PiperShareExtension/ShareViewController.swift
  - ios/PiperShareExtension/readability.js (bundled Mozilla Readability)
  - ios/PiperShareExtension/PiperShareExtension.entitlements
  - ios/Shared/CookieManager.swift (read path, already exists from ios-login)
  - ios/Shared/Models.swift
  - ios/Shared/Config.swift
  - ios/PiperShareExtension/Services/ContentExtractor.swift
  - ios/PiperShareExtension/Services/PiperAPIClient.swift
  - ios/PiperShareExtensionTests/PiperAPIClientTests.swift
  - ios/PiperShareExtensionTests/ContentExtractorTests.swift
  - ios/PiperShareExtensionTests/ShareViewControllerTests.swift
  - ios/PiperShareExtensionTests/ConfigTests.swift

## Out of Scope
- Main app UI changes
- Cookie refresh/re-login flow
- In-app reading or content preview (Belief #3)
- Offline support
- Sources beyond X/Twitter
- App Store deployment

## Notes
- readability.js: bundle from https://github.com/mozilla/readability
- Cookie injection: use WKHTTPCookieStore.setCookie() before loading
- Extension budget: ~120MB memory, ~300s time — keep WKWebView lifecycle tight
- Backend URL: use a Config struct as single source of truth
- Depends on ios-login being merged first
- See docs/IOS.md and docs/RELIABILITY.md
