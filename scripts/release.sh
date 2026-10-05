#!/bin/bash
# Prepare release assets locally. Never exports signing credentials to CI.
set -euo pipefail
cd "$(dirname "$0")/.."
version="$(cat VERSION)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid VERSION' >&2; exit 2; }
mkdir -p dist
app="$PWD/build/InputPin.app"
zip="$PWD/dist/InputPin-$version-universal.zip"
dmg="$PWD/dist/InputPin-$version-universal.dmg"
if [ -e "$zip" ] || [ -e "$dmg" ]; then
  echo 'Release output exists. Use a clean working copy; never overwrite a published asset.' >&2
  exit 2
fi
: "${SIGNING_IDENTITY:?Set your local Developer ID Application identity}"
auth=()
if [ -n "${NOTARY_PROFILE:-}" ]; then
  auth=(--keychain-profile "$NOTARY_PROFILE")
else
  : "${NOTARY_KEY_PATH:?Set NOTARY_PROFILE or local App Store Connect API key credentials}"
  : "${NOTARY_KEY_ID:?Required with NOTARY_KEY_PATH}"
  : "${NOTARY_ISSUER:?Required with NOTARY_KEY_PATH}"
  auth=(--key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER")
fi
swift test
BUILD_DIR="$PWD/build" ARCH=universal bash build.sh
ditto -c -k --keepParent "$app" "$zip"
xcrun notarytool submit "$zip" "${auth[@]}" --wait --timeout 15m
xcrun stapler staple "$app"
xcrun stapler validate "$app"
# Re-create the archive only before publication, now including the stapled ticket.
ditto -c -k --keepParent "$app" "$zip"
stage="$(mktemp -d "${TMPDIR:-/tmp}/inputpin-dmg.XXXXXX")"
# Temporary staging is left in place for inspection; it contains no credentials.
ditto "$app" "$stage/InputPin.app"
ln -s /Applications "$stage/Applications"
cp LICENSE "$stage/LICENSE.txt"
printf 'Drag InputPin to Applications, then open it.\nClick the pin in your menu bar to choose an input source.\n' > "$stage/Install.txt"
hdiutil create -volname InputPin -srcfolder "$stage" -format UDZO "$dmg"
codesign --sign "$SIGNING_IDENTITY" --timestamp "$dmg"
xcrun notarytool submit "$dmg" "${auth[@]}" --wait --timeout 15m
xcrun stapler staple "$dmg"
(cd dist && shasum -a 256 "InputPin-$version-universal.zip" "InputPin-$version-universal.dmg" > SHA256SUMS)
bash scripts/verify-release.sh
echo "Prepared assets in dist/. Review them, then publish from a version tag."
