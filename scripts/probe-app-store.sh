#!/bin/bash
# Build and validate a sandboxed feasibility probe. Never upload or publish it.
set -euo pipefail
cd "$(dirname "$0")/.."
INPUTPIN_STORE_PROBE=1 BUILD_DIR="$PWD/build/store-probe" ARCH="${ARCH:-universal}" SIGNING_IDENTITY= bash build.sh
app="$PWD/build/store-probe/InputPin.app"
codesign --display --entitlements - --xml "$app" > "$PWD/build/store-probe/entitlements.plist"
python3 - <<'PY'
from pathlib import Path
import plistlib
root = Path('build/store-probe')
entitlements = plistlib.loads((root/'entitlements.plist').read_bytes())
assert entitlements == {'com.apple.security.app-sandbox': True}, 'Unexpected sandbox entitlements'
info = plistlib.loads((root/'InputPin.app/Contents/Info.plist').read_bytes())
assert info['CFBundleIdentifier'].endswith('.SandboxProbe'), 'Probe must use its own identifier'
plistlib.loads((root/'InputPin.app/Contents/Resources/PrivacyInfo.xcprivacy').read_bytes())
print('Sandbox probe validated. This ad hoc app is not an App Store submission package.')
PY
"$app/Contents/MacOS/InputPin" --version
"$app/Contents/MacOS/InputPin" --list
echo "To test switching, quit InputPin and explicitly run:"
echo "  \"$app/Contents/MacOS/InputPin\" --integration-test"
