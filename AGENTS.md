# Working on InputPin

Read DESIGN.md before UI changes. Keep source-switching behavior in InputPinCore with deterministic tests, and macOS integrations in the app target. Never capture keyboard input or add permissions or telemetry without an explicit feature decision.

Run `swift test` and `bash build.sh` before submitting. The integration test changes the local input source and requires enabled ABC and WeType; never run it automatically in hosted CI. Release artifacts must pass signing, notarization, stapling, universal-architecture and SHA-256 checks.

Do not commit credentials, local account config, paths from a maintainer's machine or personal screenshots. Keep public documentation honest about verified behavior and compatibility. Version numbers use Semantic Versioning. Published release assets and tags are immutable; corrections get a new version.
