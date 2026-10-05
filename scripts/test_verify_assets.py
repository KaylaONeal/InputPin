#!/usr/bin/env python3
"""Negative-path tests for the public artifact validation boundary."""
import hashlib
import plistlib
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

VERIFIER = Path(__file__).with_name('verify-assets.py')

class ReleaseBoundaryTests(unittest.TestCase):
    def run_verifier(self, root):
        return subprocess.run([sys.executable, str(VERIFIER), str(root), '1.0.0'], capture_output=True, text=True)

    def fixture(self, root, version='0.9.0', bundle='io.github.kaylaoneal.InputPin'):
        zip_path = root / 'InputPin-1.0.0-universal.zip'
        with zipfile.ZipFile(zip_path, 'w') as archive:
            archive.writestr('InputPin.app/Contents/Info.plist', plistlib.dumps({
                'CFBundleIdentifier': bundle, 'CFBundleShortVersionString': version,
                'LSMinimumSystemVersion': '13.0',
            }))
        dmg_path = root / 'InputPin-1.0.0-universal.dmg'
        dmg_path.write_bytes(b'not a release')
        (root / 'SHA256SUMS').write_text(''.join(
            f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n' for path in [zip_path, dmg_path]
        ))

    def testRejectsAnOlderAppRenamedToNewRelease(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            result = self.run_verifier(root)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('identity/version mismatch', result.stderr)

    def testRejectsWrongBundleIdentifier(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root, version='1.0.0', bundle='io.someone.Else')
            result = self.run_verifier(root)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('identity/version mismatch', result.stderr)

    def testRejectsChangedDownloadEvenWithCorrectFilename(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            (root / 'InputPin-1.0.0-universal.zip').write_bytes(b'tampered')
            result = self.run_verifier(root)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Checksum mismatch', result.stderr)

    def testRejectsUnsafeManifestFilename(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'SHA256SUMS').write_text('0' * 64 + '  ../../escape.zip\n')
            result = self.run_verifier(root)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Invalid checksum manifest', result.stderr)

if __name__ == '__main__':
    unittest.main()
