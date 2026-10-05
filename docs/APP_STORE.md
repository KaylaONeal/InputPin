# Mac App Store feasibility and automation

InputPin can pursue a paid Mac App Store edition. Local sandbox tests establish technical feasibility, not App Review approval. The proposed price is **US$0.99 paid once**, with the United States as the base territory and Apple equalizing other currencies. The free MIT source and Homebrew distribution remain available.

## Verified on October 5, 2026

- A sandboxed copy of 1.0.1, with only `com.apple.security.app-sandbox`, enumerated ABC and WeType and passed the real integration test: three automatic restorations (215/500/533 ms), pause, resume, secure-input pause/recovery, and unavailable target.
- The reproducible `APP_STORE` probe also passed the same integration test (211/511/525 ms). Its universal binary has macOS 13.0 minimum deployment metadata in both architectures.
- The existing local App Store Connect API authorization returned HTTP 200. InputPin has no registered bundle ID or App Store Connect app record yet.
- The current account's Paid Apps Agreement, bank, tax, and compliance statuses were active. No agreements or banking details were changed.
- Apple Development, Apple Distribution, and Developer ID Application signing identities are present. No Mac Installer Distribution identity was found locally or through the certificate API. Developer ID notarization does not replace store signing or review.

Sleep/wake, login registration in a sandbox, VoiceOver, all supported macOS versions, the Xcode-exported store package, uploaded-build processing, review acceptance, and actual paid installation remain unverified. Test the final store-signed build with two Apple input sources as well as third-party input methods.

## Reproduce the sandbox build

```sh
bash scripts/probe-app-store.sh
```

This produces an **ad hoc feasibility probe**, not a store submission package. It uses a separate `.SandboxProbe` identifier, compiles with `APP_STORE`, disables legacy preference-domain migration, includes the privacy manifest and privacy-policy menu item, and grants no network or temporary exception entitlements. It does not upload anything or change the current input source. `ARCH=arm64` is available for a faster local probe; the default is universal.

To explicitly run the input-source integration check, first quit InputPin and enable ABC and WeType. The check temporarily switches sources and restores the original source when it finishes:

```sh
build/store-probe/InputPin.app/Contents/MacOS/InputPin --integration-test
```

## Automation boundary

| Stage | Approach | Current state |
| --- | --- | --- |
| Sandbox feasibility | Build script, entitlement verification, opt-in integration check | Implemented and locally tested |
| Initial store setup | Register macOS bundle ID; create InputPin record in the existing account | Not created; Apple documents initial app creation on its website |
| Signing and export | Xcode macOS app target using shared source/Core; `APP_STORE`, sandbox, privacy resources, Apple Distribution profile, installer signing; archive/export | Not implemented; installer certificate and provisioning still needed |
| Screenshots and listing | Controlled native screenshots with no personal desktop; English/Chinese draft in `store/listing.json` | Listing draft prepared; store screenshots not prepared |
| Upload | Xcode/Transporter CLI using the existing local API key; wait for a processed, valid build | Not implemented or uploaded |
| Pricing | Query `/v1/apps/{id}/appPricePoints` for `USA`; paginate and match decimal customer price `0.99`; create the schedule with that returned price-point ID; read it back | Desired price recorded; no live price applied |
| Metadata and review | API-managed version, listing and screenshots; verify privacy/age rating/export compliance and review contact; select the exact build; create review submission and submit | Not implemented or submitted |
| Release | Set release type to `AFTER_APPROVAL`; observe state and verify the public store listing and actual installation | Requires Apple approval; no listing is live |

After initial setup, a local release command can archive, export, upload, synchronize metadata/price, submit, and select automatic release after approval. Implement it as a resumable sequence: persist build/upload/submission IDs and artifact hashes, read remote state before writes, avoid duplicate submissions, and stop on rejected/invalid builds. An upload alone is not a successful release.

Use the already authorized Mac as the signing host. Keep private keys and certificates in its local configuration/Keychain. Public GitHub CI should test/build probes without release credentials; do not run untrusted pull-request code with a signing key or on a privileged self-hosted runner. Never commit keys, account configuration, or private review-contact details.

Apple review cannot be automated or guaranteed. New legally binding agreements and changed tax/bank/trader declarations require the account holder; recheck the current active status before a later paid release. API-managed pricing and submission can be automated once the store record and complete signed package exist. The probe does not claim that this complete release pipeline already exists.

## Review positioning

Explain the utility as maintaining a user-selected input source, with pause and secure-input behavior. It works with built-in Apple sources and does not require WeType. Do not promise control over an input method's internal Chinese/English mode. Explain that manual source changes are restored while pinned. Describe the store purchase as a convenient distribution of the open-source utility, with no locked features or subscription.

App Review makes the final judgment about utility, design and policy compliance. Avoid billing the product as access to an operating-system API. The value is the complete restoration behavior and native interface.

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
