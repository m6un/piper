# Bug Report: WKWebView extraction fails on real device

## Symptom
Content extraction fails on every attempt. The app shows "Extraction failed"
after a timeout or immediately with "Frame load interrupted."

## Environment
- iPhone running iOS 26.31
- X (Twitter) app installed on the device
- Piper built from current main branch

## Steps to Reproduce
1. Log in via XLoginView (this works fine)
2. Copy any x.com article/tweet URL
3. Open Piper, tap Pipe
4. Extraction fails every time

## Error Logs
```
Could not create a sandbox extension for '.../Piper.app'

WebPageProxy::didFailProvisionalLoadForFrame: frameID=..., isMainFrame=1,
  domain=WebKitErrorDomain, code=102, willInternallyHandleFailure=0

Error acquiring assertion: ... target is not running or doesn't have entitlement
  com.apple.developer.web-browser-engine.rendering AND ...networking AND ...webcontent

ProcessAssertion::acquireSync Failed to acquire RBS assertion
  'WebProcess NearSuspended Assertion' for process with PID=...
```

The web content process gets killed, a new one launches, and the second
navigation also fails with error 102. Eventually the operation times out.

## What Works
XLoginView successfully loads twitter.com in a WKWebView on the same device
and iOS version. The login flow completes, cookies are saved, and the user
is authenticated. The login WKWebView has no issues with navigation or
sandbox extensions.

## What Doesn't Work
ContentExtractor creates its own WKWebView programmatically and navigates it
to the URL from the clipboard. This WKWebView fails with the errors above.

## Compilation Issue
The current code does not compile. `WKError.Code.frameLoadInterruptedByPolicyChange`
does not exist as a Swift symbol — the code in `shouldRetryForFrameLoadInterruption()`
fails to build.

## Scope
- **Domain**: ios
- **Broken file**: `ios/Piper/Piper/Services/ContentExtractor.swift`
- **Working reference**: `ios/Piper/Piper/XLoginView.swift`

## Out of Scope
- Backend changes
- Login flow changes
- New features
- Config.swift changes
