# Feature Spec: ios-login

## What
Build Piper's main iOS app: a single-screen SwiftUI app with a "Connect X Account"
button that opens a WKWebView to x.com/login. On successful login, extract cookies
and persist them to the App Group (group.com.piper.app) via CookieManager.

## Why
Belief #5 — One source, one tap. User logs in once, never opens the main app again.
Belief #4 — The share extension is the product; this just enables it.

## Acceptance Criteria
- [ ] App launches with a single "Connect X Account" button
- [ ] Tapping the button presents a WKWebView loading x.com/login
- [ ] After successful login, cookies are extracted from WKWebView
- [ ] Cookies are serialized and stored in App Group UserDefaults via CookieManager
- [ ] CookieManager is the sole read/write point for cookie storage
- [ ] CookieManager lives in ios/Shared/CookieManager.swift (shared between targets)
- [ ] After login succeeds, UI shows confirmation state ("Connected")
- [ ] If login fails or is cancelled, user stays on connect screen — no silent failure
- [ ] Views never access network or storage directly
- [ ] Layer linter (lint-ios-layers.sh) passes

## Test Cases

### CookieManager Unit Tests (ios/PiperTests/CookieManagerTests.swift)

| # | Test | Input | Expected Output |
|---|------|-------|-----------------|
| 1 | Save and load round-trip | Array of HTTPCookie property dicts | `loadCookies()` returns equivalent cookies |
| 2 | Load when nothing saved | Empty UserDefaults | Returns empty array |
| 3 | Save overwrites previous | Save cookies A, then save cookies B | `loadCookies()` returns only B |
| 4 | Clear cookies | Save cookies, then `clearCookies()` | `loadCookies()` returns empty array |
| 5 | Handles corrupt data | Write garbage Data to the UserDefaults key | `loadCookies()` returns empty array, no crash |
| 6 | Has cookies check | Save valid cookies | `hasCookies` returns true |
| 7 | Has cookies when empty | Empty UserDefaults | `hasCookies` returns false |
| 8 | Cookie domain filtering | Cookies from .x.com, .twitter.com, and .google.com | Only X/Twitter cookies are saved |

### Login Detection Tests (ios/PiperTests/LoginDetectionTests.swift)

| # | Test | Input | Expected Output |
|---|------|-------|-----------------|
| 1 | Detects successful login | Navigation to x.com/home with auth cookies present | Login success callback fires |
| 2 | Ignores intermediate navigations | Navigation to x.com/login/flow/... | Login success callback does NOT fire |
| 3 | Detects cancel | WebView dismissed without reaching x.com/home | Cancel callback fires |

### ContentView State Tests (ios/PiperTests/ContentViewTests.swift)

| # | Test | Input | Expected Output |
|---|------|-------|-----------------|
| 1 | Shows connect button initially | No cookies saved | "Connect X Account" button visible |
| 2 | Shows connected state | Valid cookies in storage | "Connected" state visible |
| 3 | Updates after login | Login completes successfully | UI transitions from connect to connected |

## Scope
- **Domains**: ios only
- **Files likely touched**:
  - ios/Shared/CookieManager.swift
  - ios/Shared/Models.swift
  - ios/Piper/PiperApp.swift
  - ios/Piper/ContentView.swift
  - ios/Piper/XLoginView.swift
  - ios/Piper/Piper.entitlements
  - ios/PiperTests/CookieManagerTests.swift
  - ios/PiperTests/LoginDetectionTests.swift
  - ios/PiperTests/ContentViewTests.swift

## Out of Scope
- Share extension (separate spec)
- Readability.js extraction
- Network calls to backend
- Cookie refresh/expiry handling
- Multiple source support
- App Store deployment

## Notes
- Cookie serialization: store HTTPCookie properties array in UserDefaults
- Login detection: check for cookies from .x.com or .twitter.com after navigation to x.com/home
- Xcode project/target/entitlement setup may require manual human config
- See docs/IOS.md for architecture layers and file layout
