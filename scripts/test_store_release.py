#!/usr/bin/env python3
"""Safety regression tests: no Apple requests, credentials or input switching."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import urllib.request

from store_api import HOST, SameHostRedirect, StoreAPI, StoreError, save_private

spec = importlib.util.spec_from_file_location('store_release', Path(__file__).with_name('store-release.py'))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


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
