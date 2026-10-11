"""Verify and save the owner's media connection using the existing private login."""
import json
from pathlib import Path
import urllib.request

root = Path(__file__).resolve().parent.parent
owner = json.loads((root / '.runtime/yogen-owner.local.json').read_text())
key = json.loads((root / 'config/firebase.web.json').read_text())['FIREBASE_API_KEY']
drive = json.loads((root / 'config/drive.phase05.json').read_text())


def request(url, body, token=None):
    headers = {'Content-Type': 'text/plain' if 'script.google.com' in url else 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers=headers)
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.load(response)


token = request('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=' + key,
                {'email': owner['email'], 'password': owner['password'], 'returnSecureToken': True})['idToken']
ping = request(drive['webAppUrl'], {'action': 'ping', 'site': 'yogen', 'idToken': token})
assert ping['success'] and ping['version'] == 5 and ping['projectId'] == 'portfolio-14d15'
assert ping['rootFolderId'] == drive['rootFolderId'] and ping['maxBytes'] == 5242880
prefix = 'projects/portfolio-14d15/databases/(default)/documents/sites/yogen/'
values = {
    'settings/drive': {'webAppUrl': drive['webAppUrl'], 'rootFolderId': ping['rootFolderId'],
                       'rootFolderName': ping['rootFolderName'], 'administrativeEmail': '', 'updatedBy': owner['uid']},
    'mediaRouting/current': {'endpoint': drive['webAppUrl'], 'version': 5, 'updatedBy': owner['uid']},
}
writes = []
for name, fields in values.items():
    writes.append({'update': {'name': prefix + name, 'fields': {
        k: {'integerValue': str(v)} if isinstance(v, int) else {'stringValue': v} for k, v in fields.items()}},
        'updateTransforms': [{'fieldPath': field, 'setToServerValue': 'REQUEST_TIME'}
                             for field in (['lastTestedAt', 'updatedAt'] if name.startswith('settings/') else ['updatedAt'])]})
request('https://firestore.googleapis.com/v1/projects/portfolio-14d15/databases/(default)/documents:commit', {'writes': writes}, token)
drive['status'] = 'phase05_verified_connection'
(root / 'config/drive.phase05.json').write_text(json.dumps(drive, indent=2))
result = {'site': 'yogen', 'managerConnectionVerified': True, 'privateSettingsSaved': True,
          'publicRoutingSaved': True, 'administrativeEmailDeferred': True}
(root / 'phases/results/05/checks/owner-connection.json').write_text(json.dumps(result, indent=2))
print(json.dumps(result))
