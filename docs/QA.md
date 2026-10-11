# Release QA

This record separates executed checks from design intent. It is updated before public release.

## Local quality candidate — 1.0.3, October 11, 2026

This candidate is built locally and is not published or submitted to Apple. Checks ran on Apple Silicon, macOS 27.0, Xcode 27.0 and Swift 6.4.

- **25 Swift tests pass:** 13 core tests and 12 application-model tests. Two additional cases cover source enablement before observer registration and throttled recovery after a missed notification. New regression cases reproduce obsolete failure delays after external recovery, target change and pause/resume. Model tests cover initial-choice persistence, unavailable-source names, unchanged refreshes, paused polling, pending login approval, registration errors, preference isolation and stopping pending restoration. Workspace sleep/wake notifications are simulated in a test; they do not establish physical sleep/wake behavior.
- **19 Python safety tests pass:** 15 store-release tests and four artifact-verifier tests. New cases cover ordered three-image upload, exact-set completion, reservation resume, unknown remote assets, invalid image preflight and localized update-note validation. Shell syntax and `git diff --check` pass.
- **Universal direct and sandbox-probe builds pass:** arm64 and x86_64, strict ad hoc signature verification, version 1.0.3, utility category, privacy manifests in both bundles and macOS 13.0 minimum in Mach-O deployment metadata. SHA-256 values are recorded privately under `build/quality/artifacts.json`. This does not establish Intel runtime compatibility, Developer ID signing, notarization or release approval.
- **Final direct-build integration test passes:** three ABC → WeType restorations at 141/512/491 ms, pause/resume, secure-input suspension/recovery and unavailable-target detection.
- **Final sandbox-probe integration test passes:** three restorations at 134/501/501 ms and the same pause/resume, secure-input and unavailable-target cases. Existing instances were stopped to avoid interference, then their original app paths were relaunched and the original input source was read back after restoration.
- **44 native presentation renders generated:** English/Simplified Chinese, light/dark, 11 fixtures covering active, paused, secure, unavailable, retry, unconfirmed switch, restoration, session, login approval, long names and high-contrast appearance. Representative renders were inspected for each fixture category. The source menu uses native truncation with a complete accessibility value and tooltip; status and footer text wrap. Public light/dark preview assets were refreshed. These opaque fixture renders do not prove live translucency, actual system accessibility settings or successful screen-reader interaction.
- **Read-only App Store Connect refresh:** the previously submitted 1.0.2 version returned `READY_FOR_SALE` and `AFTER_APPROVAL`. This applies to 1.0.2, not this candidate; no paid installation was performed.

Initial native-tool attempts could not locate the preview window or timed out. A subsequent real installed-app session succeeded: one click on the selected input-method name immediately exposed ABC and WeType as menu items, without an intermediate submenu. Escape closed that menu and left the panel open. Neither source selection nor login settings were changed during this interaction check. The accessibility snapshot and screenshot confirmed pinned state and enabled native switches. Keyboard-only interaction, VoiceOver, live error-sheet handling, actual Reduce Transparency/Reduce Motion settings, physical sleep/wake and launch at login remain acceptance gates. Developer ID signing/notarization/stapling and public artifact installation also remain separate release gates.

To regenerate the offline fixture gallery after building:

```sh
python3 scripts/render-panels.py
```

The gallery is written to `build/quality/panels/index.html`. It never starts the pinning engine or registers login items.

## Executed on the maintainer's Mac

- MacBook Air, Apple Silicon, macOS 27.0, Swift 6.4.
- New app real integration test passes: ABC → WeType three times (156, 498, 511 ms), pause/resume, Secure Event Input suspension/recovery, and unavailable target feedback. The test restores the original source on exit.
- Ten deterministic core tests pass: restoration/idempotence, pause/resume, secure-input recovery, sleep/inactive session, unavailable targets, failed selection and bounded retry, successful return without a real source change, competing switches, target change, and accurate pending status.
- Both arm64 and x86_64 release binaries cross-compile; Mach-O deployment metadata records macOS 13.0.
- Shell scripts pass syntax checks.
- Developer ID signing and hardened-runtime verification complete; Apple notarization is processing. No unnotarized binary release is public.
- Public source formula passes Homebrew style/audit/install/test on a macOS 14 CI runner. Real installation from the public tap and CLI tests also pass on the maintainer's Mac.
- Four artifact-boundary tests reject a renamed old version, a wrong bundle identifier, modified bytes and an unsafe checksum filename.
- Original app icon export uses exact pixel dimensions independent of display scale; 16 px and 32 px outputs were checked.
- Light and dark native view renders inspected for hierarchy, contrast, truncation and spacing. The PNGs use a deterministic presentation fixture and an opaque material for legibility. They are not screenshots of a running session or proof of real blur/translucency.
- Project website checked in the existing Chrome session at desktop size and a 390 px viewport: images load, no horizontal overflow, and the copy-install-command button reports success with the exact one-line brew command.

## Compact panel update (1.0.1)

- Width reduced from 360 to 252 points, padding from 24 to 12 points. Example-state height is 212 points; panel area is about 69% smaller.
- Light/dark native view renders inspected; the source menu has no white backing. These exports remain opaque presentation fixtures for layout review, not live transparency screenshots.
- A live native panel was observed through Mac accessibility and its controlled-backdrop preview captured: the background shows through, and text/toggles retain full opacity. The preview contains example state, not a production source-restoration test.
- The real borderless input-source menu expands without dismissing the panel. Escape first closes that menu, then closes the panel. No source or login setting was changed in these checks.
- Own-sheet focus is protected from the normal resign-key dismissal path; live error-sheet and dropdown-selection interaction still require acceptance checks.

## Remaining acceptance checks

- Actual Apple notarization, stapling and Gatekeeper assessment.
- Exact public ZIP and DMG contents and checksums.
- Binary cask installation from the published notarized release.
- Keyboard navigation, VoiceOver, real reduced-transparency/reduced-motion settings, login startup, sleep/wake, and Intel hardware runtime.

The native UI automation connection did not locate the preview window. The initial signing process awaited local system handling that the automation tool could not inspect; Developer ID signing subsequently completed. These observations are not treated as successful UI or signing tests. Secure input during that time correctly blocked the opt-in integration test; the test later passed after secure input ended.

## Mac App Store candidate — October 5, 2026

- Xcode release archive/export: PASS, version 1.0.2 build 4, original bundle ID, matching signing team, arm64/x86_64, distribution sandbox entitlement, signed Mac Installer package. Apple processing: VALID.
- English/Chinese native presentation screenshots captured and visually reviewed at 2560 × 1600; sharp text, transparent source control, compact actual panel, no personal desktop. These use deterministic sample input sources and do not establish live restoration behavior.
- Ten Swift core tests, seven release safety tests, four artifact-verifier tests and universal development/probe builds pass. Release tests reject changed package hashes, another version's draft, manual release submission, cross-host credential redirects and cyclic pagination.
- Live metadata/price/screenshot API writes and readback passed; both screenshots completed. Privacy disclosure was published after explicit account-holder confirmation. Review submission returned WAITING_FOR_REVIEW with AFTER_APPROVAL.
- App Review approval, public store availability and actual paid installation are pending.
