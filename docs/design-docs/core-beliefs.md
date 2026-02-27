# Core Beliefs

These are non-negotiable. When in doubt, come back here.

## 1. Anonymous and Invisible
No user accounts, no content logs. The backend stores content under a random UUID and nothing else. Logs contain UUIDs and timestamps only. If subpoenaed, there is nothing interesting to find.

## 2. Ephemeral by Design
The 1-hour TTL is a feature, not a limitation. It is the privacy model. Never make it configurable, extendable, or longer by default. Content that expires cannot be misused.

## 3. Stay a Pipe
Piper is not a reader. Never build in-app reading, highlights, bookmarks, open counts, or engagement mechanics. The moment Piper becomes a reader, it competes with Instapaper instead of serving it.

## 4. The Share Extension is the Product
The main app exists solely to establish authenticated sessions. Every design and UX decision should optimise for the Share Extension flow. A clunky extension means Piper has failed, regardless of how polished the main app is.

## 5. One Source, One Tap
Onboarding for a new source must never require more than one login. If a user has to touch the main app more than once per source, onboarding has failed.

## 6. Fail Loudly
Never silently fail or retry in the background. If extraction fails, cookies are stale, or the worker is down — tell the user immediately. They need to know to try again. The extension UI must always reflect the true outcome.

## 7. Content Fidelity Over Speed
Better to take 3 extra seconds and extract cleanly than to deliver broken HTML that Instapaper cannot parse. The user's patience is highest at the share moment. Spend it on correctness.

## 8. Fewer Sources, Done Perfectly
Resist adding new source integrations until existing ones are bulletproof. One flaky source erodes trust in all of them. Depth over breadth.
