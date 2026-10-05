# Release QA

This record separates executed checks from design intent. It is updated before public release.

## Executed on the maintainer's Mac

- MacBook Air, Apple Silicon, macOS 27.0, Swift 6.4.
- Ten deterministic core tests pass: restoration/idempotence, pause/resume, secure-input recovery, sleep/inactive session, unavailable targets, failed selection and bounded retry, successful return without a real source change, competing switches, target change, and accurate pending status.
- Both arm64 and x86_64 release binaries cross-compile; Mach-O deployment metadata records macOS 13.0.
- Shell scripts pass syntax checks.
- Original app icon export uses exact pixel dimensions independent of display scale; 16 px and 32 px outputs were checked.
- Light and dark native view renders inspected for hierarchy, contrast, truncation and spacing. The PNGs use a deterministic presentation fixture and an opaque material for legibility. They are not screenshots of a running session or proof of real blur/translucency.
- Project website checked in the existing Chrome session at desktop size and a 390 px viewport: images load, no horizontal overflow, and the copy-install-command button reports success with the exact one-line brew command.

## Remaining acceptance checks

- Developer ID signing, actual Apple notarization, stapling and Gatekeeper assessment.
- Exact public ZIP and DMG contents and checksums.
- Installation from the published Homebrew tap.
- New app real ABC → WeType restoration, pause/resume and secure-input integration test.
- Native popover interaction, keyboard navigation, VoiceOver, real reduced-transparency/reduced-motion settings, login startup, sleep/wake, and Intel hardware runtime.

The native UI automation connection did not locate the preview window. The signing process also required local system handling that the automation tool could not inspect. These observations are not treated as successful UI or signing tests. Secure input during that time correctly blocked the opt-in integration test.
