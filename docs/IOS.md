# iOS Domain

## Overview
Two targets: the main app (session management only) and the Share Extension (the actual product). They share cookies via an App Group.

## Stack
- Swift, SwiftUI
- WKWebView (login + article loading)
- App Group: `group.com.piper.app`
- readability.js (bundled in Share Extension target)

## Targets

### Main App (Piper)
Single screen. Explains the product. "Connect X Account" button opens a WKWebView sheet to x.com/login. On successful login (redirect to x.com/home), cookies are extracted from WKHTTPCookieStore and persisted to the shared App Group.

### Share Extension (PiperShareExtension)
Activated from the iOS share sheet. Receives a URL. Loads it in a WKWebView injected with cookies from the App Group. Injects readability.js after page load. Extracts `{title, content}`. POSTs to the Cloudflare Worker. Copies the returned URL to UIPasteboard. Shows "Saved to Piper — paste into Instapaper".

## Cookie Architecture
- Main app writes cookies to `group.com.piper.app` UserDefaults (serialized HTTPCookie properties)
- Share Extension reads cookies and injects them into its own WKWebView's WKHTTPCookieStore
- Cookies are never sent to the backend

## File Layout
```
ios/
├── Shared/
│   ├── CookieManager.swift       ← sole read/write point for App Group cookies
│   └── Models.swift              ← shared data types
├── Piper/
│   ├── PiperApp.swift
│   ├── ContentView.swift
│   └── XLoginView.swift
├── PiperShareExtension/
│   ├── ShareViewController.swift
│   └── readability.js            ← download from Mozilla (see SETUP.md)
└── SETUP.md                      ← Xcode project setup instructions
```

## Setup
See [ios/SETUP.md](../ios/SETUP.md) for Xcode project creation, App Group configuration, and readability.js setup.
