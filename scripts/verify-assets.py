#!/usr/bin/env python3
"""Verify the exact downloadable archives, not a working build directory."""
import hashlib
import plistlib
import re
import subprocess
import sys
import tempfile
from pathlib import Path

version = sys.argv[2]
if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version):
    raise SystemExit('Invalid release version')
root = Path(sys.argv[1]).resolve()
expected = {f'InputPin-{version}-universal.zip', f'InputPin-{version}-universal.dmg'}
sums = {}
for line in (root / 'SHA256SUMS').read_text().splitlines():
    match = re.fullmatch(r'([a-f0-9]{64})  (InputPin-[0-9.]+-universal\.(?:zip|dmg))', line)
    if not match or match[2] not in expected or match[2] in sums:
        raise SystemExit('Invalid checksum manifest')
    sums[match[2]] = match[1]
if set(sums) != expected:
    raise SystemExit('Missing release checksums')
for name, checksum in sums.items():
    actual = hashlib.file_digest((root / name).open('rb'), 'sha256').hexdigest() if sys.version_info >= (3, 11) else hashlib.sha256((root / name).read_bytes()).hexdigest()
    if actual != checksum:
        raise SystemExit(f'Checksum mismatch: {name}')

def run(*args):
    subprocess.run(args, check=True)

def verify_app(app):
    with (app / 'Contents/Info.plist').open('rb') as handle:
        info = plistlib.load(handle)
    if info.get('CFBundleIdentifier') != 'io.github.kaylaoneal.InputPin' or info.get('CFBundleShortVersionString') != version:
        raise SystemExit('Release app identity/version mismatch')
    if info.get('LSMinimumSystemVersion') != '13.0':
        raise SystemExit('Unexpected deployment requirement')
    architectures = subprocess.check_output(['lipo', '-archs', str(app / 'Contents/MacOS/InputPin')], text=True).split()
    if set(architectures) != {'arm64', 'x86_64'}:
        raise SystemExit('Expected exactly arm64 and x86_64 architectures')
    run('codesign', '--verify', '--strict', str(app))
    signature = subprocess.run(['codesign', '-dv', '--verbose=2', str(app)], capture_output=True, text=True, check=True).stderr
    if 'Authority=Developer ID Application:' not in signature or 'flags=0x10000(runtime)' not in signature:
        raise SystemExit('Expected Developer ID signature and hardened runtime')
    run('xcrun', 'stapler', 'validate', str(app))
    run('spctl', '--assess', '--type', 'execute', '--verbose=2', str(app))

def manifest(app):
    result = {}
    for path in sorted(app.rglob('*')):
        if path.is_symlink():
            raise SystemExit('Unexpected app bundle symlink')
        if path.is_file():
            result[str(path.relative_to(app))] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result

with tempfile.TemporaryDirectory(prefix='inputpin-verify-') as directory:
    work = Path(directory)
    run('ditto', '-x', '-k', str(root / f'InputPin-{version}-universal.zip'), str(work / 'zip'))
    app = work / 'zip/InputPin.app'
    verify_app(app)
    dmg = root / f'InputPin-{version}-universal.dmg'
    run('xcrun', 'stapler', 'validate', str(dmg))
    mount = work / 'dmg'
    mount.mkdir()
    run('hdiutil', 'attach', '-readonly', '-nobrowse', '-mountpoint', str(mount), str(dmg))
    try:
        dmg_app = mount / 'InputPin.app'
        verify_app(dmg_app)
        if manifest(app) != manifest(dmg_app):
            raise SystemExit('DMG and ZIP contain different app bundles')
    finally:
        run('hdiutil', 'detach', str(mount))
print('PASS: exact ZIP/DMG versions, identities, architectures, signatures, tickets and SHA-256')
