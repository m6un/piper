# Product Spec

## What Piper Does
Piper lets users save paywalled or authenticated articles — initially from X (Twitter) — to Instapaper, by acting as a temporary content bridge.

## The Problem
Instapaper's share extension cannot access authenticated content. If an article lives behind a login (X's paywall, subscriber-only threads), Instapaper sees a login wall, not the article.

## How It Works
1. User logs into X once inside Piper's main app. Session cookies are stored on-device.
2. User shares an article URL from X — Piper's Share Extension activates.
3. The extension loads the article in an invisible WKWebView using the stored cookies.
4. readability.js extracts the clean article body and title.
5. Content is POSTed to a Cloudflare Worker, stored under a random UUID for 1 hour.
6. The UUID URL is copied to the user's clipboard.
7. User opens Instapaper, pastes the URL, saves normally.
8. Instapaper fetches clean HTML from the worker. Content expires after 1 hour.

## Target User
Power readers who subscribe to content on X and want it in their reading queue without friction.

## Non-Goals
- In-app reading or highlighting
- User accounts or sync
- Support for platforms beyond X until X is bulletproof
- Any content persistence beyond 1 hour
- Anything that makes Piper a destination rather than a pipe
