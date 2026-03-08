# Feature Spec: single-app-pivot

## What
Consolidate the two-target iOS architecture (main app + share extension) into a single
app target. Move extraction and API services from the share extension into the main app.
Replace App Group cookie storage with standard UserDefaults. Add a "Pipe Article" flow
that reads a URL from the clipboard, extracts content, saves to backend, and copies the
result URL to clipboard.

## Why
App Groups require a paid Apple Developer account ($99/yr). A single-app architecture
removes this dependency while preserving all functionality. Belief #4 — the pipe flow
is the product.

## Acceptance Criteria
- [ ] Single Xcode target — no share extension, no PiperShareExtension directory
- [ ] CookieManager uses standard UserDefaults (no App Group, no entitlements)
- [ ] Login flow works as before (WKWebView → x.com/login → cookie extraction)
- [ ] Connected state shows a "Pipe Article" button
- [ ] Tapping "Pipe Article" reads a URL from UIPasteboard
- [ ] If no valid URL on clipboard, shows error: "Copy an article URL from X first"
- [ ] If not logged in, shows error: "Connect your X account first"
- [ ] Loads URL in hidden WKWebView with injected cookies
- [ ] Injects readability.js and extracts {title, content}
- [ ] If extraction fails, shows error — no silent failure
- [ ] POSTs to backend /save endpoint
- [ ] On success, copies UUID URL to clipboard and shows: "Saved — paste into Instapaper"
- [ ] On failure, shows error with reason
- [ ] PipelineController orchestrates the full flow (testable, no UI dependencies)
- [ ] Backend URL is a single constant via Config.swift
- [ ] readability.js is bundled as a resource in the app target
- [ ] Views never access network or storage directly
- [ ] All tests pass

## Test Cases

### PipelineController Tests (ios/PiperTests/PipelineControllerTests.swift)

| # | Test | Input | Expected Output |
|---|------|-------|-----------------|
| 1 | No cookies | CookieManager has no cookies | Returns error: not logged in |
| 2 | Happy path | Valid cookies + mock extractor + mock API | Returns success with URL |
| 3 | Extraction failure | Valid cookies + extractor returns error | Returns extraction error |
| 4 | API failure | Valid cookies + extraction succeeds + API fails | Returns save error |
| 5 | Invalid URL | Cookies present, malformed URL string | Returns invalid URL error |

### CookieManager Tests (ios/PiperTests/CookieManagerTests.swift)

| # | Test | Input | Expected Output |
|---|------|-------|-----------------|
| 1 | Uses standard UserDefaults | Save cookies | Stored in UserDefaults.standard, not App Group |
| 2-8 | Existing tests | (keep all existing CookieManager tests) | Same expectations |

### ContentExtractor Tests (ios/PiperTests/ContentExtractorTests.swift)
Keep existing tests, move from PiperShareExtensionTests/.

### PiperAPIClient Tests (ios/PiperTests/PiperAPIClientTests.swift)
Keep existing tests, move from PiperShareExtensionTests/.

### Config Tests (ios/PiperTests/ConfigTests.swift)
Keep existing tests, move from PiperShareExtensionTests/.

## Scope
- **Domains**: ios only
- **Files to move**:
  - ios/PiperShareExtension/Services/ContentExtractor.swift → ios/Piper/Services/
  - ios/PiperShareExtension/Services/PiperAPIClient.swift → ios/Piper/Services/
  - ios/PiperShareExtension/readability.js → ios/Piper/Resources/
  - ios/PiperShareExtensionTests/*.swift → ios/PiperTests/
- **Files to modify**:
  - ios/Shared/CookieManager.swift (App Group → standard UserDefaults)
  - ios/Piper/ContentView.swift (add "Pipe Article" flow)
  - ios/PiperTests/CookieManagerTests.swift (update storage mock)
- **Files to create**:
  - ios/Piper/Services/PipelineController.swift
  - ios/Piper/PipeView.swift
  - ios/PiperTests/PipelineControllerTests.swift
- **Files to delete**:
  - ios/PiperShareExtension/ (entire directory)
  - ios/PiperShareExtensionTests/ (entire directory)
  - ios/Piper/Piper.entitlements

## Out of Scope
- Instapaper API integration (deferred — requires API key approval)
- Cookie refresh/expiry handling
- Multiple source support
- App Store deployment
- Auto-detecting clipboard changes while app is in background

## Notes
- The PipelineController should be a pure service with protocol-based dependencies
  (ContentExtracting, PiperAPIClientProtocol, CookieManager) for testability
- readability.js is already the real Mozilla Readability (replaced stub earlier)
- Backend is already deployed at the URL in Config.swift
- ShareViewController orchestration logic should inform PipelineController design,
  but PipelineController should be SwiftUI-friendly (async/completion handlers)
