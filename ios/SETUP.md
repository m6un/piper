# iOS Setup

## Prerequisites
- Xcode 15+
- Apple Developer account (for App Group entitlements)

## Xcode Project

1. Open `ios/` in Xcode (or create a new project named `Piper` targeting iOS 17+).
2. Add two targets:
   - **Piper** — iOS App (SwiftUI lifecycle)
   - **PiperShareExtension** — Share Extension

## App Group Configuration

Both targets must share the App Group `group.com.piper.app`.

1. Select the **Piper** target → Signing & Capabilities → `+ Capability` → **App Groups**.
2. Add `group.com.piper.app`.
3. Repeat for the **PiperShareExtension** target.
4. Ensure each target's `.entitlements` file contains:
   ```xml
   <key>com.apple.security.application-groups</key>
   <array>
       <string>group.com.piper.app</string>
   </array>
   ```

## readability.js

`PiperShareExtension/readability.js` must be present as a bundle resource.

1. Download `Readability.js` from the [Mozilla readability repo](https://github.com/mozilla/readability).
2. Place it at `ios/PiperShareExtension/readability.js`.
3. In Xcode, add it to the **PiperShareExtension** target's "Copy Bundle Resources" build phase.

## Build & Run

```
xcodebuild -project ios/Piper.xcodeproj -scheme Piper -destination 'platform=iOS Simulator,name=iPhone 15'
```

Tests:
```
xcodebuild test -project ios/Piper.xcodeproj -scheme PiperTests -destination 'platform=iOS Simulator,name=iPhone 15'
```
