# Release QA

This record separates executed checks from design intent. It is updated before public release.

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

## Remaining acceptance checks

- Actual Apple notarization, stapling and Gatekeeper assessment.
- Exact public ZIP and DMG contents and checksums.
- Binary cask installation from the published notarized release.
- Native popover interaction, keyboard navigation, VoiceOver, real reduced-transparency/reduced-motion settings, login startup, sleep/wake, and Intel hardware runtime.

The native UI automation connection did not locate the preview window. The initial signing process awaited local system handling that the automation tool could not inspect; Developer ID signing subsequently completed. These observations are not treated as successful UI or signing tests. Secure input during that time correctly blocked the opt-in integration test; the test later passed after secure input ended.
