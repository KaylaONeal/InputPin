#!/usr/bin/env python3
"""Archive/export the sandboxed Mac App Store edition on the signing Mac."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
from store_api import source_fingerprint

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--signing', type=Path, default=Path.home()/'.config/inputpin-release/signing.json')
    parser.add_argument('--build-number', required=True)
    args = parser.parse_args()
    if not args.build_number.isdecimal() or int(args.build_number) < 1:
        parser.error('Build number must be a positive integer')
    config = json.loads(args.signing.read_text())
    out = ROOT/'build/store-export'
    archive = ROOT/'build/InputPin.xcarchive'
    version = (ROOT/'VERSION').read_text().strip()
    source_sha256 = source_fingerprint(ROOT)
    subprocess.run(['swift', 'scripts/make-icon.swift', 'build/store-assets'], cwd=ROOT, check=True)
    subprocess.run(['xcodegen', 'generate', '--spec', 'project.yml'], cwd=ROOT, check=True)
    export = ROOT/'build/StoreExportOptions.plist'
    export.write_bytes(plistlib.dumps({
        'method': 'app-store-connect', 'destination': 'export', 'signingStyle': 'manual',
        'teamID': config['team_id'], 'signingCertificate': config['distribution_identity'],
        'installerSigningCertificate': config['installer_identity_sha1'],
        'provisioningProfiles': {'io.github.kaylaoneal.InputPin': config['profile_name']},
        'uploadSymbols': True, 'manageAppVersionAndBuildNumber': False,
    }))
    export.chmod(0o600)
    stages = [
        ('archive', ['xcodebuild', '-project', 'InputPin.xcodeproj', '-scheme', 'InputPin',
         '-configuration', 'Release', '-archivePath', str(archive),
         'DEVELOPMENT_TEAM='+config['team_id'], 'CODE_SIGN_IDENTITY='+config['distribution_identity'],
         'PROVISIONING_PROFILE_SPECIFIER='+config['profile_name'],
         'MARKETING_VERSION='+version, 'CURRENT_PROJECT_VERSION='+args.build_number, 'archive']),
        ('export', ['xcodebuild', '-exportArchive', '-archivePath', str(archive),
         '-exportPath', str(out), '-exportOptionsPlist', str(export)]),
    ]
    for name, command in stages:
        log = ROOT/f'build/store-{name}.log'
        with log.open('w') as handle:
            log.chmod(0o600)
            result = subprocess.run(command, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT)
        if result.returncode:
            raise SystemExit(f'{name} failed; inspect {log.name} locally')
        print(f'{name}: PASS', flush=True)
    app = archive/'Products/Applications/InputPin.app'
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    signed = subprocess.run(['codesign', '-d', '--entitlements', ':-', str(app)], capture_output=True, check=True)
    entitlements = plistlib.loads(signed.stdout)
    if not entitlements.get('com.apple.security.app-sandbox') or entitlements.get('com.apple.security.get-task-allow'):
        raise SystemExit('Require distribution sandbox entitlements')
    identity = subprocess.run(['codesign', '-dv', str(app)], capture_output=True, text=True, check=True).stderr
    if 'TeamIdentifier='+config['team_id'] not in identity:
        raise SystemExit('Unexpected signing team')
    info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
    if (info['CFBundleIdentifier'], info['CFBundleShortVersionString'], info['CFBundleVersion']) != (
            'io.github.kaylaoneal.InputPin', version, args.build_number):
        raise SystemExit('Unexpected archive app identity')
    binary = app/'Contents/MacOS/InputPin'
    archs = subprocess.check_output(['lipo', '-archs', str(binary)], text=True).split()
    if set(archs) != {'arm64', 'x86_64'}:
        raise SystemExit('Require an arm64 + x86_64 universal binary')
    packages = list(out.glob('*.pkg'))
    if len(packages) != 1:
        raise SystemExit('Expected exactly one exported installer')
    subprocess.run(['pkgutil', '--check-signature', str(packages[0])], check=True)
    if source_fingerprint(ROOT) != source_sha256:
        raise SystemExit('Source changed during archive/export; use a new verified build')
    manifest = out/'verified.json'
    manifest.write_text(json.dumps({'bundle_id': info['CFBundleIdentifier'], 'version': version,
        'build_number': args.build_number, 'team_id': config['team_id'],
        'source_sha256': source_sha256,
        'package_sha256': hashlib.sha256(packages[0].read_bytes()).hexdigest()}, indent=2)+'\n')
    manifest.chmod(0o600)
    print(f'Signed universal store package: {packages[0].name}')


if __name__ == '__main__':
    main()
