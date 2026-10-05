# Releasing InputPin

Only maintainers perform distribution signing. Contributors need no Apple credentials. All release credentials stay on the maintainer's Mac and are referenced locally; they are never checked into GitHub or uploaded to a hosted runner.

## Prepare

1. Review the change, run `swift test`, and check the real UI against DESIGN.md.
2. Update VERSION and CHANGELOG.md using Semantic Versioning.
3. Ensure the working tree is clean and the tested commit is merged to main.
4. Use a local Developer ID Application identity and a `notarytool` Keychain profile.

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='your-local-profile' \
bash scripts/release.sh
```

As an alternative to a Keychain profile, the script accepts NOTARY_KEY_PATH, NOTARY_KEY_ID and NOTARY_ISSUER for an existing local App Store Connect API key. Never paste the key contents into shell history or export the key to CI for convenience.

The script tests, builds arm64/x86_64, signs with hardened runtime, submits to Apple's notary service, staples tickets to the app and DMG, packages the ZIP, and verifies Gatekeeper and SHA-256. An Apple rejection is a release blocker. It never disables security protections. The preparation script does not publish anything.

## Publish

Review the package in a clean local directory. Verify that it contains only the app, license and installation instructions. Then:

```sh
git tag -a v1.0.0 -m 'InputPin 1.0.0'
git push origin v1.0.0
gh release create v1.0.0 --verify-tag --draft \
  --title 'InputPin 1.0.0' --notes-file docs/release-notes.md \
  dist/InputPin-1.0.0-universal.zip dist/InputPin-1.0.0-universal.dmg dist/SHA256SUMS
```

Download the draft assets and verify their checksums before publishing. Update the Homebrew tap with the DMG SHA-256, then publish the draft. Published assets and tags must not be overwritten; fix mistakes with a new version. The release workflow independently downloads public assets and verifies the signature, notarization, universal architectures and checksums.

The CI workflow builds development candidates with ad hoc signatures. They are explicitly not public releases. No signing credentials are required in Actions.

## Homebrew

The maintained custom tap is `KaylaONeal/homebrew-tap`. The cask points to a fixed GitHub Release URL, includes the DMG SHA-256, requires macOS Ventura or later, installs the app and optional `inputpin` CLI, and preserves preferences on ordinary uninstall.

Validate the cask with Homebrew's style/audit checks, then install from the actual public release. Do not claim acceptance into Homebrew's official catalog; custom tap installation is supported separately.
