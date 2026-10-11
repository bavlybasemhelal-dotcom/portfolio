"""Generate public server config and narrow test rules from the isolated UID."""
import json
import pathlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
user = json.loads((ROOT / '.runtime/firebase-test-user.local.json').read_text())
config = json.loads((ROOT / 'config/firebase.web.json').read_text())
original = (ROOT / '.runtime/firestore.rules').read_text()
expected = """rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
"""
assert original.strip() == expected.strip(), 'Review existing rules before inserting an experiment rule.'
folder = ROOT / 'firebase'
folder.mkdir(exist_ok=True)
(folder / 'firestore.before-phase03.rules').write_text(original)
block = """    // Isolated phase-03 account and path only; all production paths remain denied.
    match /phase03_checks/{owner}/{collection}/{record} {
      function testOwner() {
        return request.auth != null && request.auth.uid == 'UID' && owner == request.auth.uid;
      }
      allow read: if testOwner() && collection in ['runs', 'media'];
      allow create, update: if testOwner() && collection in ['runs', 'media']
        && request.resource.data.testOnly == true
        && request.resource.data.keys().hasOnly(['testOnly','createdAt','projectId','runId',
          'fileId','fileName','mimeType','fileSize','directUrl','viewUrl','downloadUrl']);
      allow delete: if testOwner() && collection in ['runs', 'media'] && resource.data.testOnly == true;
    }
""".replace('UID', user['uid'])
(folder / 'firestore.phase03.rules').write_text(original.replace('    match /{document=**}', block + '    match /{document=**}'))
(ROOT / 'firebase.phase03.json').write_text(json.dumps({'firestore': {
    'database': '(default)', 'rules': 'firebase/firestore.phase03.rules'}}, indent=2))
public = {'FIREBASE_API_KEY': config['FIREBASE_API_KEY'], 'ROOT_FOLDER_ID': '1f-aPcfkLaWly5JZGtcq-6RuSW3xsrck_',
    'TEST_FOLDER_ID': '176LcK_ck8Eerzs3PvUgk7eJwSXLOyNFz', 'ALLOWED_UIDS': user['uid']}
(ROOT / 'google_drive_script/phase03_config.js').write_text(
    '// Public configuration and a server-side experiment allowlist. No credentials.\n'
    + 'const YOGEN_PHASE03_CONFIG = ' + json.dumps(public, indent=2) + ';\n')
print(json.dumps({'generated': ['narrow test rules', 'public script configuration'], 'credentialsPrinted': False}))
