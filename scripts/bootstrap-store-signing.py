#!/usr/bin/env python3
"""Prepare Mac App Store signing locally; never revoke other certificates."""
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess

from store_api import StoreAPI, StoreError, relation, save_private

BUNDLE = 'io.github.kaylaoneal.InputPin'


def run(*args):
    return subprocess.run(args, check=True, capture_output=True).stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--credentials', type=Path)
    parser.add_argument('--state-dir', type=Path, default=Path.home()/'.config/inputpin-release')
    args = parser.parse_args()
    os.umask(0o077)
    root = args.state_dir.expanduser()
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    root.chmod(0o700)
    path = root/'signing.json'
    state = json.loads(path.read_text()) if path.exists() else {}
    api = StoreAPI(args.credentials)
    bundles = api.all('/v1/bundleIds', **{'filter[identifier]': BUNDLE})
    if len(bundles) > 1: raise StoreError('Ambiguous bundle ID registration')
    bundle = bundles[0] if bundles else api.create('bundleIds', {
        'identifier': BUNDLE, 'name': 'InputPin', 'platform': 'MAC_OS'})
    if bundle['attributes']['platform'] not in ('MAC_OS', 'UNIVERSAL'):
        raise StoreError('Require a macOS-compatible bundle ID')
    state['bundle_id_id'] = bundle['id']
    identities = run('security', 'find-identity', '-v', '-p', 'codesigning').decode()
    local = set(re.findall(r'\b[A-F0-9]{40}\b', identities))
    matches = []
    for cert in api.all('/v1/certificates', **{'filter[certificateType]': 'DISTRIBUTION'}):
        digest = hashlib.sha1(base64.b64decode(cert['attributes']['certificateContent'])).hexdigest().upper()
        if digest in local: matches.append((cert, digest))
    if state.get('distribution_certificate_id'):
        matches = [m for m in matches if m[0]['id'] == state['distribution_certificate_id']]
    if len(matches) != 1:
        raise StoreError('Require one matching Apple Distribution identity with its private key in the local Keychain')
    state.update(distribution_certificate_id=matches[0][0]['id'], distribution_identity=matches[0][1])
    save_private(path, state)
    keys = root/'signing'
    keys.mkdir(exist_ok=True, mode=0o700)
    key, csr = keys/'installer-key.pem', keys/'installer.csr'
    if not state.get('installer_certificate_id'):
        if not key.exists(): run('openssl', 'genrsa', '-out', str(key), '2048')
        key.chmod(0o600)
        run('openssl', 'req', '-new', '-key', str(key), '-out', str(csr), '-subj', '/CN=InputPin Mac Installer')
        installer = api.create('certificates', {'certificateType': 'MAC_INSTALLER_DISTRIBUTION', 'csrContent': csr.read_text()})
        state['installer_certificate_id'] = installer['id']
        save_private(path, state)
    else:
        installer = api.get('/v1/certificates/'+state['installer_certificate_id'])['data']
    if installer['attributes']['certificateType'] != 'MAC_INSTALLER_DISTRIBUTION':
        raise StoreError('Unexpected installer certificate type')
    der = base64.b64decode(installer['attributes']['certificateContent'])
    certfile = keys/'installer.cer'
    certfile.write_bytes(der); certfile.chmod(0o600)
    digest = hashlib.sha1(der).hexdigest().upper()
    if state.get('installer_identity_sha1') != digest:
        if not key.exists(): raise StoreError('Installer private key is missing on this signing Mac')
        keychain = Path.home()/'Library/Keychains/login.keychain-db'
        run('security', 'import', str(key), '-k', str(keychain), '-T', '/usr/bin/productbuild', '-T', '/usr/bin/productsign')
        run('security', 'import', str(certfile), '-k', str(keychain))
        state['installer_identity_sha1'] = digest
        save_private(path, state)
    profiles = api.all('/v1/profiles', **{'filter[name]': 'InputPin Mac App Store',
        'filter[profileType]': 'MAC_APP_STORE', 'filter[profileState]': 'ACTIVE'})
    valid = []
    for profile in profiles:
        decoded = plistlib.loads(run('security', 'cms', '-D', '-i', str(write_profile(keys, profile))))
        if decoded['ExpirationDate'].replace(tzinfo=timezone.utc) <= datetime.now(timezone.utc): continue
        certs = {hashlib.sha1(c).hexdigest().upper() for c in decoded['DeveloperCertificates']}
        if decoded['Entitlements'].get('com.apple.application-identifier', '').endswith('.'+BUNDLE) and state['distribution_identity'] in certs:
            valid.append((profile, decoded))
    if len(valid) > 1: raise StoreError('Multiple matching profiles; select one locally before continuing')
    if valid:
        profile, decoded = valid[0]
    else:
        profile = api.create('profiles', {'name': 'InputPin Mac App Store', 'profileType': 'MAC_APP_STORE'}, {
            'bundleId': relation('bundleIds', bundle['id']), 'certificates': {'data': [
                {'type': 'certificates', 'id': state['distribution_certificate_id']}]}})
        decoded = plistlib.loads(run('security', 'cms', '-D', '-i', str(write_profile(keys, profile))))
    state.update(profile_uuid=decoded['UUID'], profile_name=decoded['Name'], team_id=decoded['TeamIdentifier'][0])
    for folder in ['Library/MobileDevice/Provisioning Profiles', 'Library/Developer/Xcode/UserData/Provisioning Profiles']:
        dest = Path.home()/folder
        dest.mkdir(parents=True, exist_ok=True)
        installed = dest/(decoded['UUID']+'.provisionprofile')
        installed.write_bytes(base64.b64decode(profile['attributes']['profileContent'])); installed.chmod(0o600)
    save_private(path, state)
    print('Mac App Store signing prepared locally; no certificates revoked or credentials exported')


def write_profile(folder, profile):
    path = folder/'InputPin.provisionprofile'
    path.write_bytes(base64.b64decode(profile['attributes']['profileContent'])); path.chmod(0o600)
    return path


if __name__ == '__main__':
    try: main()
    except (StoreError, OSError, subprocess.CalledProcessError) as error: raise SystemExit(str(error))
