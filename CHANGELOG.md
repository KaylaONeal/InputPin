# Changelog

All notable changes are recorded here. Versions follow [Semantic Versioning](https://semver.org/).

## 1.0.3 — App Store review pending, 2026-10-11

### Fixed

- Open the input-source choices in one click, without an extra “Choose an input source” submenu.
- Clear obsolete failed-switch delays after an observed recovery, target change or pause/resume. Preserve failed-switch status throughout the retry delay.
- Save the initial input-source choice and retain the last known name when the source becomes unavailable.
- Recover automatically when a missing input source is re-enabled, even if its system notification is missed.
- Suspend fallback polling while paused, asleep or outside the active session; avoid redrawing unchanged UI or repeatedly enumerating sources and login items.

### Changed

- Position InputPin around pinning the user’s chosen input method, with updated English/Chinese listing names, subtitles and descriptions.
- Replace abstract store artwork with three localized panels showing the chosen input method, pinning on, and pause to switch freely.
- Use the full native popover material for readable text over desktop content; keep opaque fallbacks for reduced transparency and increased contrast.
- Show actual launch-at-login status, including pending approval; leave opening approval settings to the explicit button.
- Wrap long status labels and current-source names; expose complete source names to accessibility and tooltips. Make the privacy policy available in both distribution editions.
- Include the privacy manifest in direct builds and provide localized, deterministic panel renders for review of error, recovery and accessibility states.
- Verify installed-user read and execute permissions in the signed App Store installer before upload.

## 1.0.2 — 2026-10-05

### Added

- Mac App Store Xcode archive/export, local signing setup, verified installer upload, bilingual native screenshots, live US$0.99 pricing, and resumable review submission. Version 1.0.2 build 4 is waiting for Apple review with automatic release after approval.
- Reproducible sandbox feasibility probe and CI validation, privacy manifest and policy.
- Store-specific compilation skips legacy preference-domain migration and provides an in-app privacy-policy link. The probe is ad hoc signed and cannot be submitted as a store package.

### Fixed

- Presentation fixtures cannot switch the system input source, write pinning preferences or register login items.

## 1.0.1 — 2026-10-05

### Changed

- Compact 252-point panel with tighter spacing, single-line settings and a transparent input-source menu.
- A transparent native panel replaces the opaque system popover backing. Text and controls retain full opacity; reduced transparency and increased contrast use an opaque background.
- Clicking elsewhere or pressing Escape dismisses the panel. Reopening the app reveals it.

## 1.0.0 — 2026-10-05

### Added

- Automatic restoration of a selected macOS input source across source changes, app activation and session recovery.
- A native translucent SwiftUI/AppKit popover with pause/resume, source selection and opt-in launch at login.
- English and Simplified Chinese interface copy, light/dark appearance and system accessibility preferences.
- Secure-input and inactive-session suspension, bounded retries and unavailable-source feedback.
- Universal Apple Silicon/Intel distribution, direct DMG downloads and a Homebrew tap.
- Deterministic core tests, an opt-in real input-source integration test, and public contribution/security policies.
