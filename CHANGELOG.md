# Changelog

All notable changes are recorded here. Versions follow [Semantic Versioning](https://semver.org/).

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
