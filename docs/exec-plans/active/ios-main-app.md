# Feature Spec: ios-main-app

## What
Build the Piper main iOS app target: a single-screen SwiftUI app that explains the product and handles X account login. The app presents a "Connect X Account" button that opens a WKWebView sheet to x.com/login. On successful login (detected by redirect to x.com/home), cookies are extracted from WKHTTPCookieStore and persisted to the shared App Group (`group.com.piper.app`) via CookieManager. The main app's sole purpose is session establishment.

## Why
Belief #4 — The Share Extension is the product. The main app exists only to establish authenticated sessions. Belief #5 — One Source, One Tap: users must be able to authenticate with a single login flow. Belief #6 — Fail Loudly: the app must surface login state clearly.

## Acceptance Criteria
- [ ] `ContentView.swift` shows a brief product description and a "Connect X Account" button
- [ ] Tapping the button opens `XLoginView.swift` as a sheet containing a WKWebView
- [ ] `XLoginView.swift` loads `https://x.com/login` in the WKWebView on appear
- [ ] When WKWebView redirects to a URL containing `x.com/home`, the sheet dismisses automatically
- [ ] On redirect to x.com/home, cookies from WKHTTPCookieStore are passed to `CookieManager.save(_:)`
- [ ] `CookieManager.swift` is the sole file that reads/writes the App Group UserDefaults key `group.com.piper.app`
- [ ] `CookieManager.save(_:)` serializes HTTPCookie properties and writes to App Group UserDefaults
- [ ] `CookieManager.load()` returns deserialized `[HTTPCookie]` from App Group UserDefaults
- [ ] `ContentView.swift` displays "X account connected" when `CookieManager.load()` returns non-empty cookies
- [ ] `Models.swift` defines any shared data types used across app and extension targets
- [ ] iOS layer linter (`lint-ios-layers.sh`) passes — Views must not reference URLSession, UserDefaults, or FileManager directly
- [ ] Only `CookieManager.swift` references `UserDefaults` or `group.com.piper.app`

## Scope
- **Domains**: ios only
- **Files to create**:
  - `ios/Shared/CookieManager.swift`
  - `ios/Shared/Models.swift`
  - `ios/Piper/PiperApp.swift`
  - `ios/Piper/ContentView.swift`
  - `ios/Piper/XLoginView.swift`

## Out of Scope
- Actual Xcode project file (`.xcodeproj`) — Swift source files only
- Share Extension code — that is a separate spec
- Any endpoint beyond the X login flow
- Logout or session invalidation UI
- Error recovery for partial cookie states
- Any UI beyond the single connection screen
- Support for platforms other than X

## Notes
- App Group identifier: `group.com.piper.app`
- UserDefaults suite name for App Group: `group.com.piper.app`
- Key for storing cookies: `"cookies"` in App Group UserDefaults
- Cookie serialization: use `HTTPCookie.properties` (a `[HTTPCookiePropertyKey: Any]` dict) and store as `[[String: Any]]` using `PropertyListSerialization` or similar
- X login success detection: WKNavigationDelegate `decidePolicyFor` — check if URL host contains `x.com` and path contains `/home`
- See ARCHITECTURE.md iOS layer rules and docs/IOS.md for cookie architecture
- The layer linter checks that `*View.swift` files do not call URLSession, UserDefaults, or FileManager directly
