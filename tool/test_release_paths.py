"""Exercise release configuration on temporary files; no app builds or packages."""
import json
from pathlib import Path
import tempfile
import unittest

from release_paths import release_identity, sync_hosting_paths, web_release_dir


class ReleasePathsTest(unittest.TestCase):
    def test_both_configs_follow_version_without_changing_other_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'pubspec.yaml').write_text('version: 2.3.4+56\n', encoding='utf-8')
            before = {'hosting': {'public': 'releases/company-projects/web',
                                  'headers': [{'source': '**', 'headers': []}],
                                  'redirects': [{'source': '/download', 'type': 302}]},
                      'firestore': {'rules': 'firebase/firestore.company-media.rules'}}
            for name in ['firebase.json', 'firebase.company.json']:
                (root / name).write_text(json.dumps(before), encoding='utf-8')
            self.assertEqual(release_identity(root), ('2.3.4', 56))
            self.assertEqual(web_release_dir(root), root / 'releases/2.3.4/web')
            self.assertEqual(sync_hosting_paths(root), 'releases/2.3.4/web')
            expected = {**before, 'hosting': {**before['hosting'],
                                            'public': 'releases/2.3.4/web'}}
            for name in ['firebase.json', 'firebase.company.json']:
                self.assertEqual(json.loads((root / name).read_text()), expected)
            # Synchronization only edits configuration; it must not create builds.
            self.assertFalse((root / 'releases').exists())
            original = (root / 'firebase.json').read_bytes()
            sync_hosting_paths(root)
            self.assertEqual((root / 'firebase.json').read_bytes(), original)
            (root / 'pubspec.yaml').write_text('version: 2.3.5+57\n', encoding='utf-8')
            self.assertEqual(sync_hosting_paths(root), 'releases/2.3.5/web')

    def test_invalid_version_does_not_change_configuration(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'pubspec.yaml').write_text('version: broken\n', encoding='utf-8')
            file = root / 'firebase.json'
            file.write_text('{"hosting":{"public":"untouched"}}', encoding='utf-8')
            before = file.read_bytes()
            with self.assertRaises(ValueError):
                sync_hosting_paths(root)
            self.assertEqual(file.read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
