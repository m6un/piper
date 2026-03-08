# Retro: single-app-pivot

**Date**: 2026-03-08
**PR**: #7
**Cycles**: 1/3 (with 1 inner fix cycle after verify)
**Outcome**: PASS

## Summary

Consolidated the two-target iOS architecture (main app + share extension) into a single
app target. The builder delivered a complete implementation in one cycle: moved
ContentExtractor and PiperAPIClient into the Piper target, replaced AppGroupStorage with
StandardStorage (UserDefaults.standard), created PipelineController, PipeView, and a full
PipelineControllerTests suite covering all 5 spec cases. Verify failed on two issues that
both turned out to be harness gaps rather than code defects: backend npm dependencies were
not installed before running tsc/eslint/vitest, and the iOS layer linter incorrectly
flagged UserDefaults references in test files. A fix agent resolved both without touching
any application code. The reviewer gave PASS.

## Cycle log

### Cycle 1
- **Builder output**: Full single-app pivot — CookieManager.swift (AppGroupStorage →
  StandardStorage), ContentExtractor.swift and PiperAPIClient.swift moved to
  ios/Piper/Services/, readability.js moved to ios/Piper/Resources/, PipelineController.swift
  created, PipeView.swift created, ContentView.swift updated with Pipe Article button,
  PipelineControllerTests.swift (5 test cases), CookieManagerTests.swift updated with Test 9,
  all PiperShareExtensionTests moved to PiperTests with updated imports,
  PiperShareExtension/ and Piper.entitlements deleted, lint-ios-layers.sh updated to exclude
  test files from Rule 2.
- **Verify result**: FAIL
  - (a) Backend tools (tsc, eslint, vitest) not installed — `npm install` had not been run in
    `backend/` before `run-verify.sh` invoked `npm run type-check`, `npm run lint`, `npm test`.
  - (b) `lint-ios-layers.sh` Rule 2 flagged `CookieManagerTests.swift` for referencing
    `UserDefaults` — the test legitimately verifies that `StandardStorage` writes to
    `UserDefaults.standard`, but the linter's exclusion for test files was only added in the
    same PR, so the original script was applied against the new test code.
- **Reviewer verdict**: PASS (after inner fix cycle resolved both verify failures)
- **Findings**: Two harness gaps (see Root cause analysis)

## Root cause analysis

| # | Finding | Category | Severity | Systematic? | Proposed fix |
|---|---------|----------|----------|-------------|--------------|
| 1 | `run-verify.sh` runs `npm run type-check / lint / test` in `backend/` without first ensuring `node_modules` is present. On a fresh worktree (no `npm install`) all three commands fail with "cannot find module" errors, producing noisy false failures that are entirely unrelated to the feature under review. | Linter gap | Med | Yes — every backend-touching feature in a fresh worktree will hit this | Add `npm install --silent` (or `npm ci --silent`) to `run-verify.sh` before running backend npm scripts |
| 2 | `lint-ios-layers.sh` Rule 2 had no exemption for test files. The new `CookieManagerTests.swift` test (Test 9) directly asserts that `UserDefaults.standard` is written — a legitimate and necessary test. The linter flagged it as a violation. The fix (add `*Tests.swift` exclusion) was applied in the same PR, so verify was run against the pre-fix script. | Linter gap | Low | Yes — any future test that verifies storage behavior will be flagged without this exclusion | Already fixed in PR #7 (`lint-ios-layers.sh` now excludes `*Tests.swift` from Rule 2) — no further action needed |

## What worked well

- The builder's cycle 1 implementation was architecturally clean: services abstracted behind
  protocols (`CookieProviding`, `ContentExtracting`, `PiperAPIClientProtocol`), views never
  touching network or storage, PipelineController fully decoupled from UI, and a single
  `Config.backendBaseURL` constant unchanged from the previous architecture.
- All 5 PipelineController test cases (notLoggedIn, happy path, extractionFailed, saveFailed,
  invalidURL) were delivered on the first pass with correct error message strings matching the
  spec verbatim.
- The builder correctly identified that `CookieManagerTests.swift` Test 9 needed to directly
  reference `UserDefaults.standard` to verify storage behavior, and proactively updated the
  linter to accommodate this — a self-correcting move that required no reviewer input.
- Neither verify failure was a code defect. Both were harness gaps, and the fix was clean and
  contained.

## Harness issues

1. **`run-verify.sh` does not install backend dependencies**: On every fresh worktree, `npm
   run type-check`, `npm run lint`, and `npm test` will fail if `node_modules` is absent. This
   has no pre-check or auto-install step. The failure is misleading because it looks like a
   code error rather than a missing dependency.

2. **`lint-ios-layers.sh` Rule 2 did not exempt test files**: A test that asserts storage
   behavior must reference the storage mechanism by design. The original script had no carve-out
   for this pattern. This is now fixed in the codebase, but it caused an unnecessary verify
   failure and a fix cycle.

## Actions

- [ ] `.claude/scripts/run-verify.sh`: Before the backend type-check / lint / test block, add
  `npm install --silent` (or `npm ci --silent`) inside the `backend/` subshell so that a fresh
  worktree with no `node_modules` does not produce spurious failures. (root cause: finding #1)
