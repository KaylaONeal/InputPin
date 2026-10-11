#!/usr/bin/env python3
"""Safety regression tests: no Apple requests, credentials or input switching."""
import importlib.util
import hashlib
import json
from pathlib import Path
import tempfile
import struct
import unittest
import zlib
from unittest.mock import patch
import urllib.request

from store_api import HOST, SameHostRedirect, StoreAPI, StoreError, save_private

spec = importlib.util.spec_from_file_location('store_release', Path(__file__).with_name('store-release.py'))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


def write_screenshot(path, color):
    def chunk(kind, value):
        return struct.pack('>I', len(value))+kind+value+struct.pack('>I', zlib.crc32(kind+value))
    row = b'\x00'+bytes(color)*1280
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR', struct.pack('>IIBBBBB', 1280, 800, 8, 2, 0, 0, 0))
                     +chunk(b'IDAT', zlib.compress(row*800))+chunk(b'IEND', b''))


class ScreenshotAPI:
    def __init__(self):
        self.shots = []
        self.created = []
        self.order = []

    def all(self, path, **kwargs):
        if path.endswith('/appScreenshotSets'):
            return [{'id': 'set', 'attributes': {'screenshotDisplayType': 'APP_DESKTOP'}}]
        return self.shots

    def create(self, kind, attrs, relationships):
        self.created.append(attrs['fileName'])
        shot = {'id': str(len(self.shots)+1), 'attributes': {
            **attrs, 'assetDeliveryState': {'state': 'AWAITING_UPLOAD'}, 'uploadOperations': []}}
        self.shots.append(shot)
        return shot

    def patch(self, kind, identity, attrs):
        next(shot for shot in self.shots if shot['id'] == identity)['attributes'].update(attrs)

    def request(self, method, path, body):
        self.order = [item['id'] for item in body['data']]
        by_id = {shot['id']: shot for shot in self.shots}
        self.shots = [by_id[identity] for identity in self.order]


class StoreUpdateNotesSafety(unittest.TestCase):
    def runner(self, remote):
        runner = release.Release.__new__(release.Release)
        runner.listing = {'localizations': {'en-US': {'whatsNew': 'One-click choices.'},
                                          'zh-Hans': {'whatsNew': '一次点击展开输入法。'}}}
        runner.localizations = lambda: [
            {'attributes': {'locale': locale, 'whatsNew': text}} for locale, text in remote.items()]
        return runner

    def test_requires_matching_notes_in_every_locale(self):
        runner = self.runner({'en-US': 'One-click choices.', 'zh-Hans': '一次点击展开输入法。'})
        runner.verify_update_notes()
        for remote in ({'en-US': 'One-click choices.'},
                       {'en-US': 'Previous version.', 'zh-Hans': '一次点击展开输入法。'}):
            with self.assertRaises(StoreError): self.runner(remote).verify_update_notes()

    def test_missing_local_notes_stop_metadata_before_writes(self):
        runner = self.runner({})
        del runner.listing['localizations']['zh-Hans']['whatsNew']
        runner.api = unittest.mock.Mock()
        with self.assertRaises(StoreError): runner.metadata()
        runner.api.create.assert_not_called()
        runner.api.patch.assert_not_called()


class StoreScreenshotSafety(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.folder = self.root/'en-US'
        self.folder.mkdir()
        for index, name in enumerate(['01-pin.png', '02-choose.png', '03-pause.png']):
            write_screenshot(self.folder/name, (index*80, 120, 200))
        self.runner = release.Release.__new__(release.Release)
        self.runner.app = 'inputpin'
        self.runner.version_id = 'draft'
        self.runner.release = {'attributes': {'appStoreState': 'PREPARE_FOR_SUBMISSION'}}
        self.runner.args = type('Args', (), {'screenshots': self.root})()
        self.runner.localizations = lambda: [{'id': 'localization', 'attributes': {'locale': 'en-US'}}]
        self.runner.api = ScreenshotAPI()
        self.private = patch.object(release, 'PRIVATE', self.root)
        self.private.start()

    def tearDown(self):
        self.private.stop()
        self.temp.cleanup()

    def test_uploads_all_three_in_order_and_requires_all_to_complete(self):
        self.runner.screenshots()
        self.assertEqual(self.runner.api.created, ['01-pin.png', '02-choose.png', '03-pause.png'])
        self.assertEqual(self.runner.api.order, ['1', '2', '3'])
        self.assertFalse(self.runner.screenshots_ready())
        for shot in self.runner.api.shots:
            shot['attributes']['assetDeliveryState']['state'] = 'COMPLETE'
        self.assertTrue(self.runner.screenshots_ready())
        self.runner.api.shots.pop()
        self.assertFalse(self.runner.screenshots_ready())

    def test_completed_uploads_resume_without_duplicate_reservations(self):
        self.runner.screenshots()
        for shot in self.runner.api.shots:
            shot['attributes']['assetDeliveryState']['state'] = 'COMPLETE'
        self.runner.api.shots.reverse()
        self.runner.screenshots()
        self.assertEqual(len(self.runner.api.created), 3)
        self.assertEqual(self.runner.api.order, ['1', '2', '3'])

    def test_pending_reservation_resumes_from_checkpoint(self):
        digest = hashlib.md5((self.folder/'01-pin.png').read_bytes()).hexdigest()
        shot = self.runner.api.create('appScreenshots', {'fileName': '01-pin.png'}, {})
        save_private(self.root/f'screenshot-inputpin-draft-en-US-{digest}.json', {'screenshot_id': shot['id']})
        self.runner.screenshots()
        self.assertEqual(len(self.runner.api.created), 3)

    def test_invalid_later_image_prevents_any_upload(self):
        (self.folder/'03-pause.png').write_bytes(b'not a screenshot')
        with self.assertRaises(StoreError): self.runner.screenshots()
        self.assertEqual(self.runner.api.created, [])

    def test_unrelated_remote_asset_is_never_removed(self):
        self.runner.api.shots = [{'id': 'other', 'attributes': {'sourceFileChecksum': 'other'}}]
        with self.assertRaises(StoreError): self.runner.screenshots()
        self.assertEqual(self.runner.api.created, [])
        self.assertEqual(self.runner.api.shots[0]['id'], 'other')

    def test_wrong_dimensions_and_duplicate_content_are_rejected(self):
        first = self.folder/'01-pin.png'
        raw = first.read_bytes()
        first.write_bytes(raw[:16]+struct.pack('>II', 100, 100)+raw[24:])
        with self.assertRaises(StoreError): self.runner.screenshots()
        first.write_bytes(raw)
        (self.folder/'02-choose.png').write_bytes(raw)
        with self.assertRaises(StoreError): self.runner.screenshots()
        self.assertEqual(self.runner.api.created, [])


class StoreReleaseSafety(unittest.TestCase):
    def test_auth_never_redirects_off_apple_api(self):
        req = urllib.request.Request(HOST+'/v1/apps', headers={'Authorization': 'Bearer private'})
        with self.assertRaises(StoreError):
            SameHostRedirect().redirect_request(req, None, 302, '', {}, 'https://example.org/capture')

    def test_pagination_rejects_cycles(self):
        api = StoreAPI.__new__(StoreAPI)
        api.get = lambda *a, **k: {'data': [], 'links': {'next': HOST+'/v1/apps?cursor=loop'}}
        with self.assertRaises(StoreError): api.all('/v1/apps')

    def test_private_checkpoint_replaces_complete_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'state.json'
            save_private(path, {'stage': 'reserved'})
            save_private(path, {'stage': 'complete'})
            self.assertEqual(json.loads(path.read_text()), {'stage': 'complete'})
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_other_version_draft_is_not_renamed(self):
        api = type('API', (), {'all': lambda _, path, **kw: (
            [{'id': 'inputpin'}] if path == '/v1/apps' else [{'id': 'other-draft',
                'attributes': {'versionString': '9.9.9', 'appStoreState': 'PREPARE_FOR_SUBMISSION'}}])})()
        args = type('Args', (), {'credentials': None})()
        with patch.object(release, 'StoreAPI', return_value=api):
            runner = release.Release(args)
        self.assertIsNone(runner.release)
        with self.assertRaises(StoreError): runner.metadata()

    def test_manual_release_is_not_submitted(self):
        runner = release.Release.__new__(release.Release)
        runner.version = '1.0.2'
        runner.release = {'attributes': {'versionString': '1.0.2',
            'appStoreState': 'PREPARE_FOR_SUBMISSION', 'releaseType': 'MANUAL'}}
        with self.assertRaises(StoreError): runner.submit()

    def test_changed_package_is_not_uploaded(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            package = folder/'InputPin.pkg'; package.write_bytes(b'changed-package')
            (folder/'verified.json').write_text(json.dumps({'bundle_id': 'io.github.kaylaoneal.InputPin',
                'version': '1.0.2', 'build_number': '4', 'team_id': 'EXAMPLE', 'package_sha256': 'bad-hash'}))
            (folder/'signing.json').write_text(json.dumps({'team_id': 'EXAMPLE'}))
            runner = release.Release.__new__(release.Release)
            runner.version = '1.0.2'; runner.listing = {'bundleId': 'io.github.kaylaoneal.InputPin'}
            runner.args = type('Args', (), {'package': package, 'build_number': '4'})()
            with patch.object(release, 'PRIVATE', folder), patch.object(release.subprocess, 'run') as process:
                with self.assertRaises(StoreError): runner.upload()
                process.assert_not_called()

    def test_existing_build_requires_matching_source_checkpoint(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            (folder/'upload.json').write_text(json.dumps({'app_id': 'inputpin', 'version': '1.0.2',
                'build_number': '4', 'source_sha256': 'old-source'}))
            runner = release.Release.__new__(release.Release)
            runner.app = 'inputpin'; runner.version = '1.0.2'
            runner.args = type('Args', (), {'build_number': '4'})()
            with patch.object(release, 'PRIVATE', folder), patch.object(release, 'source_fingerprint', return_value='new-source'):
                with self.assertRaises(StoreError): runner.verify_uploaded_source()


if __name__ == '__main__': unittest.main()
