# Product Spec

## What Piper Does
Piper lets users save paywalled or authenticated articles — initially from X (Twitter) — to Instapaper, by acting as a temporary content bridge.

## The Problem
Instapaper's share extension cannot access authenticated content. If an article lives behind a login (X's paywall, subscriber-only threads), Instapaper sees a login wall, not the article.

## How It Works
1. User logs into X once inside Piper. Session cookies are stored on-device.
2. User copies an article URL from the X app.
3. User opens Piper — app reads the URL from clipboard.
4. Piper loads the article in an invisible WKWebView using the stored cookies.
5. readability.js extracts the clean article body and title.
6. Content is POSTed to a Cloudflare Worker, stored under a random UUID for 1 hour.
7. The UUID URL is copied to the user's clipboard.
8. User opens Instapaper, pastes the URL, saves normally.
9. Instapaper fetches clean HTML from the worker. Content expires after 1 hour.

## Target User
Power readers who subscribe to content on X and want it in their reading queue without friction.

## Non-Goals
- In-app reading or highlighting
- User accounts or sync
- Support for platforms beyond X until X is bulletproof
- Any content persistence beyond 1 hour
- Anything that makes Piper a destination rather than a pipe
