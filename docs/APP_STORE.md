# Mac App Store release automation

InputPin **1.0.2 (build 4)** was submitted on October 5, 2026 and is **Waiting for Review**. The United States base price is **US$0.99 paid once**. Release is configured as `AFTER_APPROVAL`; Apple approval and regional eligibility determine actual availability. No store download or paid installation has been verified yet. The MIT source and Homebrew source installation remain free.

## Verified

- Registered InputPin's application identity and created its App Store Connect record (Apple ID `6819264969`).
- Generated and installed Mac Installer Distribution signing and a Mac App Store profile on the signing Mac. Existing Apple Distribution signing is used for the app. Private keys stay in the local Keychain/configuration.
- Xcode archived/exported a signed sandboxed universal arm64/x86_64 installer, with macOS 13 minimum deployment, a privacy manifest and no network or temporary exception entitlements. Apple processed build 4 as `VALID`.
- Uploaded English and Simplified Chinese descriptions and controlled native screenshots at 2560 × 1600. Screenshots show the actual SwiftUI controls using a presentation fixture; no personal desktop content is included.
- Read back the live USA price point and confirmed USD 0.99. Selected all 175 territories; Apple's regional restrictions still apply.
- Published the factual “Data Not Collected” privacy disclosure after the account holder confirmed Apple's accuracy/update commitment. Set age rating, copyright, utility category, export-compliance declaration, and review instructions. The app requires no login.
- Submitted the exact processed build 4 for version 1.0.2; Apple's API returned `WAITING_FOR_REVIEW` and `AFTER_APPROVAL`.
- Ten core tests and seven release safety tests pass. The sandbox feasibility probe previously passed three real restorations (211/511/525 ms), pause/resume, secure-input recovery and unavailable-source handling.

Sleep/wake on real hardware, sandboxed login registration, VoiceOver, every supported macOS version, App Review acceptance and an actual paid installation remain unverified. Developer ID notarization for the direct-download channel is separate from store signing and review.

## One-time signing setup

Install full Xcode and `brew install xcodegen`. Use an App Store Connect API key already authorized for the relevant team. Create a private local JSON configuration with `private_key_path`, `key_id` and `issuer_id`; protect the key with mode 600. Reference the file with `INPUTPIN_APPLE_CONFIG`; never paste key contents into commands, GitHub, CI or chat.

```sh
python3 scripts/bootstrap-store-signing.py
```

The script registers the app ID if absent, matches an existing local Apple Distribution private-key identity against Apple's certificate API, creates a local installer key/certificate if needed, and installs the matching profile. It never revokes other certificates. Multiple or missing identities stop the process for local inspection. The initial app record and privacy questionnaire use Apple's website; that one-time setup is complete for InputPin. Legal commitments require the account holder's confirmation.

Store the four review contact fields (`contactFirstName`, `contactLastName`, `contactPhone`, `contactEmail`) in a private local `review-contact.json` under the release state directory. These fields go only to Apple for review, never into public source. The default private state directory is `~/.config/inputpin-release`.

## Release a version

Update `VERSION`, `CHANGELOG.md` and listing copy. Review/test the source and refresh screenshots if the UI changes. Commit the verified source before a production release. An existing editable version must match `VERSION`; another version draft is never silently renamed.

```sh
python3 scripts/store-release.py release --build-number 4
```

Use a new build number for a changed binary. This command creates or uses the exact version, synchronizes metadata, archives/exports with manual local signing, sets/read-verifies USD 0.99, initializes availability if absent, uploads the reviewed local screenshots, uploads the verified package if the build is absent, waits up to 30 minutes for Apple processing, selects that exact valid Mac build, and submits for automatic release after approval. Already submitted versions are read-only. An invalid build or an Apple validation error stops the command; it does not cancel a review, overwrite another draft, revoke credentials or bypass a missing requirement.

Check status or resume an individual stage:

```sh
python3 scripts/store-release.py status
python3 scripts/store-release.py screenshots
python3 scripts/store-release.py submit --build-number 4
```

Other stages are `metadata`, `price`, `availability` and `upload`. `python3 scripts/build-store.py --build-number 4` prepares the package without uploading. The exporter validates app identity, version/build, signing team, sandbox, universal architectures and installer signing; the upload command checks its manifest, source fingerprint and SHA-256 before contacting Apple. Reusing an uploaded build requires a matching local app/version/build/source checkpoint, preventing submission of an old binary after a source edit. Build and screenshot processing both share the wait deadline. Screenshot reservations are checkpointed immediately and resumed by app/version/locale/hash.

The reviewed English/Chinese PNGs live in the ignored `build/store-screenshots` directory on the signing Mac, named `en-US.png` and `zh-Hans.png`; `--screenshots /path/to/assets` selects another directory. Prepare these once during maintainer setup. The current assets have already been uploaded to Apple. `--store-preview` opens the real native controls in a controlled presentation canvas and does not start source switching or register login items. Refresh assets using the native screenshot tool, and convert to opaque RGB PNG if needed. Presentation windows are solely screenshot fixtures; the normal menu bar popup remains 252 points wide.

## Contributor validation

```sh
swift test
python3 scripts/test_store_release.py
ARCH=universal bash build.sh
bash scripts/probe-app-store.sh
```

The probe is ad hoc signed under a separate `.SandboxProbe` identity and cannot be submitted to the store. Its default validation only enumerates sources. A deliberate local `--integration-test` temporarily switches sources, requires enabled ABC/WeType and all InputPin instances to be quit, and restores the original source. Never run input switching in hosted CI.

Public GitHub CI runs credential-free tests and builds. It never receives Apple private keys or executes untrusted pull requests on the signing host. Check active account agreements before a later paid release. Apple review is external; automatic release after approval does not guarantee acceptance or a release date.

## Official references

- [Review Guidelines: 2.4.5, 4.2, 4.10 and 5.1.1](https://developer.apple.com/app-store/review/guidelines/)
- [Configure App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)
- [Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)
- [Set a price](https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [App price points](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-apps-_id_-apppricepoints)
- [Create a review submission](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-reviewsubmissions)
- [Certificate types](https://developer.apple.com/help/account/create-certificates/certificates-overview)
- [Required-reason API declarations](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)
