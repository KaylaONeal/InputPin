# Contributing to InputPin

Thanks for helping make input on macOS more predictable. Bug reports, accessibility feedback, translations and code improvements are welcome.

## Before you start

Search existing issues. For a substantial behavior change, open a feature request first so we can agree on the problem. Never include passwords, typed text, keychain exports, or private signing credentials in issues.

## Build and test

Requirements: macOS 13+, Xcode Command Line Tools with Swift 5.9+.

```sh
git clone https://github.com/KaylaONeal/InputPin.git
cd InputPin
swift test
bash build.sh
open build/InputPin.app
```

`ARCH=universal bash build.sh` cross-compiles both architectures. Development builds use an ad hoc signature. Apple distribution credentials are not needed for contributing.

The opt-in integration test changes your actual input source. Quit all running InputPin instances, enable ABC and WeType, and avoid typing while it runs:

```sh
build/InputPin.app/Contents/MacOS/InputPin --integration-test
```

It checks real restoration, pause/resume, secure-input handling and unavailable targets, then restores the original source. Hosted CI runs deterministic unit tests; it does not pretend to verify third-party input methods.

## Pull requests

1. Create a branch from `main`.
2. Keep one focused change per pull request.
3. Test behavior changes, especially unsafe transitions and failure paths.
4. Update English and Chinese copy together. Follow [DESIGN.md](DESIGN.md).
5. Include the problem, resulting behavior, test evidence, and screenshots for UI changes.

Swift uses four-space indentation, explicit state names, and small types. Do not add keyboard capture, network analytics, global shortcuts, or broad permissions without first discussing the need. Respect the [Code of Conduct](CODE_OF_CONDUCT.md).

## Release policy

Published versions follow Semantic Versioning. Release assets must be universal, Developer ID signed, Apple notarized, stapled, and checksum verified. Build candidates in CI are not public releases. The maintainer prepares distribution on their own Mac; private keys never enter the repository or CI logs. See [docs/RELEASING.md](docs/RELEASING.md).
