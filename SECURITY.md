# Security policy

## Supported versions

Security fixes target the latest stable release. Please upgrade before reporting a problem that has already been fixed.

## Report a vulnerability

Use **Security → Report a vulnerability** on the GitHub repository to submit a private report. If private reporting is unavailable, use [GitHub Support](https://support.github.com/) for a confidential reporting route. Do not disclose exploitable details in a public issue before a fix is available.

Include the affected version, macOS version, reproduction steps, impact, and a minimal demonstration. Never attach personal keystrokes, credentials, or private signing material. Maintainers will acknowledge and coordinate disclosure as availability permits; there is no paid support or guaranteed response SLA.

## Scope and permissions

InputPin reads the selected input-source identifier, observes macOS input-source and workspace notifications, and selects the user's target input source. It does not capture keys, inspect documents, read passwords, or make network requests. No Accessibility, Input Monitoring, admin, or account access is required. A temporary mouse-click monitor dismisses the menu panel when clicking another app; it is removed on dismissal and does not observe global keyboard events or retain mouse-event data.

Secure Event Input takes priority. On secure input, inactive sessions, or sleep, automatic switching is suspended. macOS login screens are outside the app's scope. Certain applications keep secure input enabled longer than a password field; InputPin waits until the system releases it.

Release signing and notarization credentials stay outside source control. Homebrew downloads pinned release assets and checks SHA-256. Do not remove Gatekeeper protections to run an untrusted build.
