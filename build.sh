#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
version="$(cat VERSION)"
arch="${ARCH:-$(uname -m)}"
case "$arch" in arm64|x86_64|universal) ;; *) echo "Unsupported architecture: $arch" >&2; exit 2 ;; esac
build_dir="${BUILD_DIR:-$PWD/build}"
app="$build_dir/InputPin.app"
store_flags=()
bundle_id="io.github.kaylaoneal.InputPin"
if [ "${INPUTPIN_STORE_PROBE:-0}" = 1 ]; then
  if [ -n "${SIGNING_IDENTITY:-}" ]; then
    echo "Store probes use ad hoc signing only; export a real store build through Xcode." >&2
    exit 2
  fi
  store_flags=(-Xswiftc -DAPP_STORE)
  bundle_id="$bundle_id.SandboxProbe"
fi
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
build_arch() {
  swift build -c release --arch "$1" ${store_flags[@]+"${store_flags[@]}"}
  bin_dir="$(swift build -c release --arch "$1" ${store_flags[@]+"${store_flags[@]}"} --show-bin-path)"
  cp "$bin_dir/InputPin" "$build_dir/InputPin-$1"
}
if [ "$arch" = universal ]; then
  build_arch arm64
  build_arch x86_64
  lipo -create "$build_dir/InputPin-arm64" "$build_dir/InputPin-x86_64" -output "$app/Contents/MacOS/InputPin"
else
  build_arch "$arch"
  cp "$build_dir/InputPin-$arch" "$app/Contents/MacOS/InputPin"
fi
swift scripts/make-icon.swift "$app/Contents/Resources"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$bundle_id</string>
<key>CFBundleName</key><string>InputPin</string>
<key>CFBundleDisplayName</key><string>InputPin</string>
<key>CFBundleExecutable</key><string>InputPin</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>Copyright © 2026 InputPin contributors. MIT License.</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string></array>
</dict></plist>
PLIST
if [ "${INPUTPIN_STORE_PROBE:-0}" = 1 ]; then
  cp store/PrivacyInfo.xcprivacy "$app/Contents/Resources/PrivacyInfo.xcprivacy"
  codesign --force --options runtime --entitlements store/InputPin.entitlements --sign - "$app"
elif [ -n "${SIGNING_IDENTITY:-}" ]; then
  codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$app"
else
  codesign --force --sign - "$app"
fi
codesign --verify --strict "$app"
echo "$app"
