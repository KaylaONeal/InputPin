#!/usr/bin/env python3
"""Resumable InputPin App Store release operations; run on the signing Mac."""
import argparse
from decimal import Decimal
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.request

from store_api import StoreAPI, StoreError, relation, save_private, source_fingerprint

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = Path.home()/'.config/inputpin-release'
EDITABLE = {'PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED'}


class Release:
    def __init__(self, args):
        self.args = args
        self.api = StoreAPI(args.credentials)
        self.listing = json.loads((ROOT/'store/listing.json').read_text())
        self.version = (ROOT/'VERSION').read_text().strip()
        apps = self.api.all('/v1/apps', **{'filter[bundleId]': self.listing['bundleId']})
        if len(apps) != 1:
            raise StoreError('Create the InputPin app record in App Store Connect first')
        self.app = apps[0]['id']
        versions = self.api.all(f'/v1/apps/{self.app}/appStoreVersions', **{'filter[platform]': 'MAC_OS'})
        matches = [v for v in versions if v['attributes']['versionString'] == self.version]
        if matches:
            self.release = matches[0]
        else:
            self.release = None
        self.version_id = self.release['id'] if self.release else None
        self.other_drafts = [v for v in versions if v['attributes']['appStoreState'] in EDITABLE
                            and v['attributes']['versionString'] != self.version]

    def editable(self):
        if not self.release or self.release['attributes']['appStoreState'] not in EDITABLE:
            raise StoreError('Require an editable Mac App Store version')

    def localizations(self):
        return self.api.all(f'/v1/appStoreVersions/{self.version_id}/appStoreVersionLocalizations')

    def metadata(self):
        if not self.release:
            if self.other_drafts:
                raise StoreError('Another editable version exists; refusing to overwrite it')
            self.release = self.api.create('appStoreVersions', {
                'platform': 'MAC_OS', 'versionString': self.version, 'releaseType': 'AFTER_APPROVAL'},
                {'app': relation('apps', self.app)})
            self.version_id = self.release['id']
        self.editable()
        self.api.patch('appStoreVersions', self.version_id, {
            'versionString': self.version, 'copyright': '2026 InputPin contributors',
            'releaseType': self.listing['releaseType'], 'reviewType': 'APP_STORE'})
        info = next(i for i in self.api.all(f'/v1/apps/{self.app}/appInfos')
                    if i['attributes']['appStoreState'] in EDITABLE)
        self.api.patch('appInfos', info['id'], relationships={
            'primaryCategory': relation('appCategories', self.listing['category'])})
        self.api.patch('apps', self.app, {'contentRightsDeclaration': 'DOES_NOT_USE_THIRD_PARTY_CONTENT'})
        infos = {i['attributes']['locale']: i for i in self.api.all(f'/v1/appInfos/{info["id"]}/appInfoLocalizations')}
        versions = {v['attributes']['locale']: v for v in self.localizations()}
        for locale, text in self.listing['localizations'].items():
            attrs = {k: text[k] for k in ['name', 'subtitle']}
            attrs['privacyPolicyUrl'] = 'https://kaylaoneal.github.io/InputPin/privacy.html'
            self.upsert('appInfoLocalizations', infos.get(locale), attrs, locale, 'appInfo', 'appInfos', info['id'])
            # Apple creates a matching version localization when an app-info locale is added.
            versions = {v['attributes']['locale']: v for v in self.localizations()}
            attrs = {k: text[k] for k in ['description', 'keywords']}
            attrs.update({'supportUrl': 'https://github.com/KaylaONeal/InputPin/issues',
                          'marketingUrl': 'https://kaylaoneal.github.io/InputPin/'})
            self.upsert('appStoreVersionLocalizations', versions.get(locale), attrs, locale,
                        'appStoreVersion', 'appStoreVersions', self.version_id)
        rating = self.api.get(f'/v1/appInfos/{info["id"]}/ageRatingDeclaration')['data']
        booleans = ['advertising', 'gambling', 'healthOrWellnessTopics', 'lootBox', 'messagingAndChat',
                    'parentalControls', 'ageAssurance', 'socialMedia', 'socialMediaAgeRestricted',
                    'unrestrictedWebAccess', 'userGeneratedContent']
        enums = ['alcoholTobaccoOrDrugUseOrReferences', 'contests', 'gamblingSimulated', 'gunsOrOtherWeapons',
                 'medicalOrTreatmentInformation', 'profanityOrCrudeHumor', 'sexualContentGraphicAndNudity',
                 'sexualContentOrNudity', 'horrorOrFearThemes', 'matureOrSuggestiveThemes',
                 'violenceCartoonOrFantasy', 'violenceRealisticProlongedGraphicOrSadistic', 'violenceRealistic',
                 'ageRatingOverrideV2', 'koreaAgeRatingOverride']
        self.api.patch('ageRatingDeclarations', rating['id'],
                       dict({k: False for k in booleans}, **{k: 'NONE' for k in enums}))
        contact = json.loads(self.args.contact.read_text())
        fields = ['contactFirstName', 'contactLastName', 'contactPhone', 'contactEmail']
        if not all(contact.get(k) for k in fields):
            raise StoreError('Require a complete private review contact')
        attrs = {k: contact[k] for k in fields}
        attrs.update({'demoAccountRequired': False, 'notes': self.listing['reviewNotes']})
        detail = self.api.get(f'/v1/appStoreVersions/{self.version_id}/appStoreReviewDetail').get('data')
        if detail:
            self.api.patch('appStoreReviewDetails', detail['id'], attrs)
        else:
            self.api.create('appStoreReviewDetails', attrs, {
                'appStoreVersion': relation('appStoreVersions', self.version_id)})
        print('English/Chinese metadata, privacy URL, age rating and review instructions saved')

    def upsert(self, kind, existing, attrs, locale, rel, reltype, identity):
        if existing:
            self.api.patch(kind, existing['id'], attrs)
        else:
            self.api.create(kind, dict(attrs, locale=locale), {rel: relation(reltype, identity)})

    def price(self):
        self.editable()
        points = self.api.all(f'/v1/apps/{self.app}/appPricePoints',
                             **{'filter[territory]': 'USA', 'limit': 200})
        price = Decimal(self.listing['pricing']['customerPrice'])
        point = next((p for p in points if Decimal(p['attributes']['customerPrice']) == price), None)
        if not point:
            raise StoreError('Apple does not currently offer the requested USA price point')
        # JSON:API local identifiers refer to an included inline resource, not a server price ID.
        local = '${inputpin-price}'
        self.api.create('appPriceSchedules', relationships={
            'app': relation('apps', self.app), 'baseTerritory': relation('territories', 'USA'),
            'manualPrices': {'data': [{'type': 'appPrices', 'id': local}]}}, included=[{
            'type': 'appPrices', 'id': local, 'attributes': {'startDate': None, 'endDate': None},
            'relationships': {'appPricePoint': relation('appPricePoints', point['id'])}}])
        schedule = self.api.get(f'/v1/apps/{self.app}/appPriceSchedule')['data']
        manual = self.api.get(f'/v1/appPriceSchedules/{schedule["id"]}/manualPrices', include='appPricePoint')
        actual = [p for p in manual.get('included', []) if p['type'] == 'appPricePoints']
        if not actual or not any(Decimal(p['attributes']['customerPrice']) == price for p in actual):
            raise StoreError('Could not verify the saved price')
        save_private(PRIVATE/'price.json', {'app_id': self.app, 'price_point_id': point['id'], 'price': str(price)})
        print(f'USA price verified: USD {price}; other storefronts use Apple equalization')

    def availability(self):
        self.editable()
        try:
            existing = self.api.get(f'/v1/apps/{self.app}/appAvailabilityV2')['data']
        except StoreError as error:
            if not str(error).startswith('Apple HTTP 404:'): raise
            existing = None
        if existing:
            regions = self.api.all(f'/v2/appAvailabilities/{existing["id"]}/territoryAvailabilities', limit=200)
            print(f'Existing availability retained: {sum(bool(r["attributes"]["available"]) for r in regions)} selected territories')
            return
        territories = self.api.all('/v1/territories', limit=200)
        included, references = [], []
        for territory in territories:
            local = '${inputpin-'+territory['id']+'}'
            references.append({'type': 'territoryAvailabilities', 'id': local})
            included.append({'type': 'territoryAvailabilities', 'id': local,
                'attributes': {'available': True, 'preOrderEnabled': False},
                'relationships': {'territory': relation('territories', territory['id'])}})
        self.api.request('POST', '/v2/appAvailabilities', {'data': {'type': 'appAvailabilities',
            'attributes': {'availableInNewTerritories': True}, 'relationships': {
                'app': relation('apps', self.app), 'territoryAvailabilities': {'data': references}}}, 'included': included})
        print(f'Availability selected for {len(territories)} territories; Apple determines regional eligibility')

    def screenshots(self):
        self.editable()
        for loc in self.localizations():
            locale = loc['attributes']['locale']
            path = self.args.screenshots/f'{locale}.png'
            if not path.is_file():
                raise StoreError(f'Missing screenshot: {locale}.png')
            raw = path.read_bytes()
            if raw[:8] != b'\x89PNG\r\n\x1a\n' or raw[25] not in (0, 2):
                raise StoreError('Screenshots must be opaque RGB PNGs')
            sets = self.api.all(f'/v1/appStoreVersionLocalizations/{loc["id"]}/appScreenshotSets')
            target = next((s for s in sets if s['attributes']['screenshotDisplayType'] == 'APP_DESKTOP'), None)
            if not target:
                target = self.api.create('appScreenshotSets', {'screenshotDisplayType': 'APP_DESKTOP'}, {
                    'appStoreVersionLocalization': relation('appStoreVersionLocalizations', loc['id'])})
            digest = hashlib.md5(raw).hexdigest()
            checkpoint = PRIVATE/f'screenshot-{self.app}-{self.version_id}-{locale}-{digest}.json'
            shots = self.api.all(f'/v1/appScreenshotSets/{target["id"]}/appScreenshots')
            existing = next((s for s in shots if s['attributes'].get('sourceFileChecksum') == digest), None)
            if not existing and checkpoint.exists():
                saved = json.loads(checkpoint.read_text())
                existing = next((s for s in shots if s['id'] == saved['screenshot_id']), None)
                if not existing:
                    raise StoreError('Saved screenshot reservation is missing; inspect before reserving another')
            if existing and existing['attributes']['assetDeliveryState']['state'] == 'COMPLETE':
                print(f'{locale} screenshot already complete'); continue
            shot = existing or self.api.create('appScreenshots', {'fileName': path.name, 'fileSize': len(raw)}, {
                'appScreenshotSet': relation('appScreenshotSets', target['id'])})
            save_private(checkpoint, {'screenshot_id': shot['id']})
            for op in shot['attributes'].get('uploadOperations') or []:
                if not op['url'].startswith('https://'):
                    raise StoreError('Require HTTPS screenshot upload')
                req = urllib.request.Request(op['url'], method=op['method'],
                    data=raw[op['offset']:op['offset']+op['length']],
                    headers={h['name']: h['value'] for h in op.get('requestHeaders', [])})
                with urllib.request.urlopen(req, timeout=120) as response: response.read()
            self.api.patch('appScreenshots', shot['id'], {'sourceFileChecksum': digest, 'uploaded': True})
            print(f'{locale} screenshot committed; Apple processing')

    def upload(self):
        package = self.args.package.resolve()
        if not package.is_file() or package.suffix != '.pkg':
            raise StoreError('Require the signed exported .pkg')
        manifest = json.loads((package.parent/'verified.json').read_text())
        signing = json.loads((PRIVATE/'signing.json').read_text())
        if (manifest['bundle_id'], manifest['version'], manifest['build_number'], manifest['team_id']) != (
                self.listing['bundleId'], self.version, self.args.build_number, signing['team_id']):
            raise StoreError('Verified package identity does not match this release')
        if hashlib.sha256(package.read_bytes()).hexdigest() != manifest['package_sha256']:
            raise StoreError('Exported package changed after verification')
        if manifest.get('source_sha256') != source_fingerprint(ROOT):
            raise StoreError('Source changed since package verification; use a new verified build')
        subprocess.run(['pkgutil', '--check-signature', str(package)], check=True, capture_output=True)
        command = ['xcrun', 'altool', '--upload-package', str(package), '--api-key', self.api.config['key_id'],
                   '--api-issuer', self.api.config['issuer_id'], '--p8-file-path', str(self.api.key), '--output-format', 'json']
        log = ROOT/'build/store-upload.log'
        with log.open('w') as handle:
            log.chmod(0o600)
            result = subprocess.run(command, stdout=handle, stderr=subprocess.STDOUT)
        if result.returncode:
            raise StoreError('Upload failed; inspect build/store-upload.log locally')
        save_private(PRIVATE/'upload.json', {'app_id': self.app,
            'sha256': hashlib.sha256(package.read_bytes()).hexdigest(), 'version': self.version,
            'build_number': self.args.build_number, 'source_sha256': manifest['source_sha256']})
        print('Upload accepted; check status after Apple finishes processing')

    def submit(self):
        if self.release and self.release['attributes']['appStoreState'] in {
                'WAITING_FOR_REVIEW', 'IN_REVIEW', 'PENDING_APPLE_RELEASE', 'PROCESSING_FOR_APP_STORE', 'READY_FOR_SALE'}:
            selected = self.api.get(f'/v1/appStoreVersions/{self.version_id}/build').get('data')
            if not selected or selected['attributes']['version'] != self.args.build_number:
                raise StoreError('A different build is already submitted; refusing to replace it')
            self.status(); return
        self.editable()
        if self.release['attributes']['versionString'] != self.version:
            raise StoreError('Metadata version does not match VERSION')
        if self.release['attributes']['releaseType'] != 'AFTER_APPROVAL':
            raise StoreError('Require automatic release after approval before submission')
        self.verify_uploaded_source()
        builds = self.api.all('/v1/builds', **{'filter[app]': self.app,
            'filter[version]': self.args.build_number, 'limit': 200})
        candidates = []
        for build in builds:
            pre = self.api.get(f'/v1/builds/{build["id"]}/preReleaseVersion')['data']['attributes']
            if pre['version'] == self.version and pre['platform'] == 'MAC_OS': candidates.append(build)
        if len(candidates) != 1 or candidates[0]['attributes']['processingState'] != 'VALID':
            raise StoreError('Require exactly one VALID Mac build with the requested version/build number')
        build = candidates[0]
        encryption = build['attributes'].get('usesNonExemptEncryption')
        if encryption is True:
            raise StoreError('Build encryption declaration conflicts with this app; inspect before submitting')
        if encryption is None:
            self.api.patch('builds', build['id'], {'usesNonExemptEncryption': False})
        selected = self.api.get(f'/v1/appStoreVersions/{self.version_id}/build').get('data')
        if not selected or selected['id'] != build['id']:
            self.api.patch('appStoreVersions', self.version_id, relationships={'build': relation('builds', build['id'])})
        if not self.screenshots_ready():
            raise StoreError('All localization screenshots must finish processing first')
        submissions = self.api.all(f'/v1/apps/{self.app}/reviewSubmissions', **{'filter[platform]': 'MAC_OS'})
        pending = [s for s in submissions if s['attributes']['state'] == 'READY_FOR_REVIEW']
        if len(pending) > 1:
            raise StoreError('Multiple review drafts; inspect before submitting')
        submission = pending[0] if pending else self.api.create('reviewSubmissions', {'platform': 'MAC_OS'}, {'app': relation('apps', self.app)})
        items = self.api.all(f'/v1/reviewSubmissions/{submission["id"]}/items', include='appStoreVersion')
        if not items:
            self.api.create('reviewSubmissionItems', relationships={
                'reviewSubmission': relation('reviewSubmissions', submission['id']),
                'appStoreVersion': relation('appStoreVersions', self.version_id)})
        else:
            for item in items:
                linked = item.get('relationships', {}).get('appStoreVersion', {}).get('data')
                if not linked or linked['id'] != self.version_id:
                    raise StoreError('Review draft contains other content; refusing to submit it')
        self.api.patch('reviewSubmissions', submission['id'], {'submitted': True})
        print('Review submission sent; release is configured automatically after approval')
        self.status()

    def status(self):
        for v in self.api.all(f'/v1/apps/{self.app}/appStoreVersions'):
            a = v['attributes']; print(a['platform'], a['versionString'], a['appStoreState'], a['releaseType'])
        for b in self.api.all(f'/v1/apps/{self.app}/builds', limit=200):
            print('Build', b['attributes']['version'], b['attributes']['processingState'])

    def verify_uploaded_source(self):
        record = json.loads((PRIVATE/'upload.json').read_text())
        expected = (self.app, self.version, self.args.build_number, source_fingerprint(ROOT))
        actual = tuple(record.get(k) for k in ['app_id', 'version', 'build_number', 'source_sha256'])
        if actual != expected:
            raise StoreError('Existing build has no matching upload/source checkpoint; choose a new build number')

    def screenshots_ready(self):
        ready = True
        for loc in self.localizations():
            sets = self.api.all(f'/v1/appStoreVersionLocalizations/{loc["id"]}/appScreenshotSets')
            shots = [shot for s in sets for shot in self.api.all(f'/v1/appScreenshotSets/{s["id"]}/appScreenshots')]
            states = [shot['attributes']['assetDeliveryState']['state'] for shot in shots]
            if 'FAILED' in states: raise StoreError('Apple rejected screenshot processing; inspect the reserved asset')
            if not states or any(s != 'COMPLETE' for s in states): ready = False
        return ready

    def release_all(self):
        if self.release and self.release['attributes']['appStoreState'] in {'WAITING_FOR_REVIEW', 'IN_REVIEW',
                'PENDING_APPLE_RELEASE', 'PROCESSING_FOR_APP_STORE', 'READY_FOR_SALE'}:
            self.status(); return
        self.metadata()
        subprocess.run(['python3', str(ROOT/'scripts/build-store.py'),
                        '--build-number', self.args.build_number], cwd=ROOT, check=True)
        self.price()
        self.availability()
        self.screenshots()
        builds = self.api.all('/v1/builds', **{'filter[app]': self.app,
            'filter[version]': self.args.build_number, 'filter[preReleaseVersion.version]': self.version})
        if not builds: self.upload()
        else: self.verify_uploaded_source()
        deadline = time.monotonic()+self.args.wait_seconds
        while True:
            fresh = Release(self.args)
            builds = self.api.all('/v1/builds', **{'filter[app]': self.app,
                'filter[version]': self.args.build_number, 'filter[preReleaseVersion.version]': self.version})
            if any(b['attributes']['processingState'] in ('INVALID', 'FAILED') for b in builds):
                raise StoreError('Apple rejected build processing; inspect App Store Connect')
            if builds and all(b['attributes']['processingState'] == 'VALID' for b in builds) and fresh.screenshots_ready():
                fresh.submit()
                return
            if time.monotonic() >= deadline:
                raise StoreError('Apple build/screenshot processing still pending; resume with submit after checking status')
            print('Waiting for Apple build/screenshot processing...', flush=True)
            time.sleep(30)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=['metadata', 'price', 'availability', 'screenshots', 'upload', 'submit', 'status', 'release'])
    p.add_argument('--credentials', type=Path)
    p.add_argument('--contact', type=Path, default=PRIVATE/'review-contact.json')
    p.add_argument('--screenshots', type=Path, default=ROOT/'store/screenshots')
    p.add_argument('--package', type=Path, default=ROOT/'build/store-export/InputPin.pkg')
    p.add_argument('--build-number', default='1')
    p.add_argument('--wait-seconds', type=int, default=1800)
    args = p.parse_args()
    if not args.build_number.isdecimal() or int(args.build_number) < 1 or args.wait_seconds < 0:
        p.error('Require a positive integer build number and a nonnegative wait duration')
    try: getattr(Release(args), 'release_all' if args.action == 'release' else args.action)()
    except (StoreError, OSError, subprocess.CalledProcessError) as error:
        p.exit(1, f'{error}\n')


if __name__ == '__main__': main()
