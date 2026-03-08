# iOS Domain

## Overview
Single app target. Handles X login, content extraction, and backend communication. No share extension, no App Groups.

## Stack
- Swift, SwiftUI
- WKWebView (login + article loading)
- UserDefaults (cookie persistence)
- readability.js (bundled in app)

## App Flow

### Login (one-time)
"Connect X Account" button opens a WKWebView sheet to x.com/login. On successful login (redirect to x.com/home), cookies are extracted from WKHTTPCookieStore and persisted to UserDefaults via CookieManager.

### Pipe (every use)
User copies article URL from X app, opens Piper. App reads clipboard, loads URL in a hidden WKWebView with injected cookies. readability.js extracts `{title, content}`. POSTs to Cloudflare Worker. Copies returned UUID URL to clipboard. Shows "Saved — paste into Instapaper".

## Cookie Architecture
- App writes and reads cookies via CookieManager using standard UserDefaults
- Cookies are serialized HTTPCookie property dictionaries
- Cookies are never sent to the backend

## File Layout
```
ios/
├── Shared/
│   ├── Config.swift                  ← backend URL constant
│   ├── CookieManager.swift           ← sole read/write point for cookies
│   └── Models.swift                  ← ExtractedContent, SaveResponse, ConnectionState
├── Piper/
│   ├── PiperApp.swift                ← entry point
│   ├── ContentView.swift             ← login state + "Pipe Article" button
│   ├── XLoginView.swift              ← WKWebView login sheet
│   ├── PipeView.swift                ← extraction flow UI
│   ├── Services/
│   │   ├── ContentExtractor.swift    ← WKWebView + readability.js extraction
│   │   ├── PiperAPIClient.swift      ← HTTP POST /save client
│   │   └── PipelineController.swift  ← orchestration: extract → save → clipboard
│   └── Resources/
│       └── readability.js            ← Mozilla Readability
└── PiperTests/
    ├── CookieManagerTests.swift
    ├── ContentViewTests.swift
    ├── LoginDetectionTests.swift
    ├── ContentExtractorTests.swift
    ├── PiperAPIClientTests.swift
    ├── ConfigTests.swift
    └── PipelineControllerTests.swift
```

## Setup
Single Xcode target. No entitlements required. No App Group configuration. See [ios/SETUP.md](../ios/SETUP.md) for Xcode project setup.
