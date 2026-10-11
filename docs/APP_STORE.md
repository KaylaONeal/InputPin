# Mac App Store release automation

InputPin **1.0.2 (build 4)** was submitted on October 5, 2026. A read-only App Store Connect API check on October 11 returned **`READY_FOR_SALE`**, with `AFTER_APPROVAL` release. The configured United States base price is **US$0.99 paid once**; regional availability, a store download and paid installation have not been verified. Local changes for **1.0.3** remain unreleased. The MIT source and Homebrew source installation remain free.

## Verified

- Registered InputPin's application identity and created its App Store Connect record (Apple ID `6819264969`).
- Generated and installed Mac Installer Distribution signing and a Mac App Store profile on the signing Mac. Existing Apple Distribution signing is used for the app. Private keys stay in the local Keychain/configuration.
- Xcode archived/exported a signed sandboxed universal arm64/x86_64 installer, with macOS 13 minimum deployment, a privacy manifest and no network or temporary exception entitlements. Apple processed build 4 as `VALID`.
- Uploaded English and Simplified Chinese descriptions and controlled native screenshots at 2560 × 1600. Screenshots show the actual SwiftUI controls using a presentation fixture; no personal desktop content is included.
- Read back the live USA price point and confirmed USD 0.99. Selected all 175 territories; Apple's regional restrictions still apply.
- Published the factual “Data Not Collected” privacy disclosure after the account holder confirmed Apple's accuracy/update commitment. Set age rating, copyright, utility category, export-compliance declaration, and review instructions. The app requires no login.
- Submitted the exact processed build 4 for version 1.0.2; Apple's API returned `WAITING_FOR_REVIEW` and `AFTER_APPROVAL`.
- Ten core tests and seven release safety tests pass. The sandbox feasibility probe previously passed three real restorations (211/511/525 ms), pause/resume, secure-input recovery and unavailable-source handling.

Sleep/wake on real hardware, sandboxed login registration, VoiceOver, every supported macOS version and an actual paid installation remain unverified. App Review state was refreshed on October 11: `READY_FOR_SALE`. Developer ID notarization for the direct-download channel is separate from store signing and review.

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
python3 scripts/store-release.py release --build-number 5
```

Use a new build number for a changed binary. This command creates or uses the exact version, synchronizes metadata, archives/exports with manual local signing, sets/read-verifies USD 0.99, initializes availability if absent, uploads the reviewed local screenshots, uploads the verified package if the build is absent, waits up to 30 minutes for Apple processing, selects that exact valid Mac build, and submits for automatic release after approval. Already submitted versions are read-only. An invalid build or an Apple validation error stops the command; it does not cancel a review, overwrite another draft, revoke credentials or bypass a missing requirement.

Check status or resume an individual stage:

```sh
python3 scripts/store-release.py status
python3 scripts/store-release.py screenshots
python3 scripts/store-release.py submit --build-number 5
```

Other stages are `metadata`, `price`, `availability` and `upload`. `python3 scripts/build-store.py --build-number 5` prepares the package without uploading. The exporter validates app identity, version/build, signing team, sandbox, universal architectures and installer signing; the upload command checks its manifest, source fingerprint and SHA-256 before contacting Apple. Reusing an uploaded build requires a matching local app/version/build/source checkpoint, preventing submission of an old binary after a source edit. Build and screenshot processing both share the wait deadline. Screenshot reservations are checkpointed immediately and resumed by app/version/locale/hash.

The next-version assets contain three ordered opaque RGB PNGs per locale. Native presentation exports are 2560 × 1600; supplied English hero artwork is 1280 × 800. They show the selected input method with pinning on, choosing and enabling pinning, and pausing to switch freely. The updated names, subtitles, descriptions, localized update notes and review instructions are in `store/listing.json`; this file describes the local draft, not the current live App Store version.

```sh
python3 scripts/render-store-screenshots.py --app build/InputPin.app
# Optional: preserve provided artwork as the first English image.
python3 scripts/render-store-screenshots.py --app build/InputPin.app --hero-image /path/to/artwork.png
```

Review `build/store-screenshots/index.html`. The images are `en-US/01-pin.png`, `en-US/02-choose.png`, `en-US/03-pause.png`, and the corresponding files under `zh-Hans/`. Generated images contain actual native controls in deterministic presentation states with an illustrative display frame; they are not real-device screenshots or source-restoration evidence. The export never starts source switching, changes preferences or registers login items. The normal popup remains 252 points wide.

The release script uploads locale folders in filename order, verifies the saved order, resumes existing reservations, and requires the exact local set to finish processing before submission. It validates all local images before uploading. Submission also reads back the localized update notes and requires them to match the listing. It supports the legacy single-image `en-US.png` / `zh-Hans.png` layout when no locale folder exists. `--screenshots /path/to/assets` selects another directory. If an editable draft contains different assets, the script stops for inspection instead of deleting them. Published versions and release assets remain immutable. These new assets have not been uploaded or submitted.

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
