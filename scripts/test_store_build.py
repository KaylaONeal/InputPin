#!/usr/bin/env python3
"""Permission regressions for store artifacts; no Apple signing or API calls."""
import importlib.util
from pathlib import Path
import stat
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('store_build', Path(__file__).with_name('build-store.py'))
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class StorePayloadPermissions(unittest.TestCase):
    def test_restrictive_build_is_readable_and_executable_after_normalization(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary)/'InputPin.app'
            content = app/'Contents'
            content.mkdir(parents=True)
            executable = content/'InputPin'
            executable.write_bytes(b'executable fixture')
            resource = content/'Info.plist'
            resource.write_bytes(b'resource fixture')
            for path in (app, content, executable): path.chmod(0o700)
            resource.chmod(0o600)
            with self.assertRaises(ValueError): build.verify_bundle_permissions(app)
            build.make_bundle_readable(app)
            build.verify_bundle_permissions(app)
            self.assertEqual(stat.S_IMODE(executable.stat().st_mode), 0o755)
            self.assertEqual(stat.S_IMODE(resource.stat().st_mode), 0o644)

    def test_normalization_never_changes_files_outside_the_bundle(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary)/'InputPin.app'
            app.mkdir()
            private = Path(temporary)/'private.json'
            private.write_bytes(b'private fixture')
            private.chmod(0o600)
            (app/'link').symlink_to(private)
            build.make_bundle_readable(app)
            self.assertEqual(stat.S_IMODE(private.stat().st_mode), 0o600)


if __name__ == '__main__': unittest.main()
