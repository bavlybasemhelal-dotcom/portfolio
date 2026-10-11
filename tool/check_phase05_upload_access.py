"""Probe actual upload authorization before touching Drive; no tokens in evidence."""
import base64
import hashlib
import json
from pathlib import Path
import urllib.request

root = Path(__file__).resolve().parent.parent
fixture = json.loads((root / '.runtime/phase05-browser.local.json').read_text())
key = json.loads((root / 'config/firebase.web.json').read_text())['FIREBASE_API_KEY']
url = json.loads((root / 'config/drive.phase05.json').read_text())['webAppUrl']


def call(url, body):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={'Content-Type': 'text/plain' if 'script.google.com' in url else 'application/json'})
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.load(response)


email = hashlib.sha256(fixture['outsiderLogin'].encode()).hexdigest() + '@login.yogen.invalid'
token = call('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=' + key,
             {'email': email, 'password': fixture['password'], 'returnSecureToken': True})['idToken']
body = {'action': 'upload', 'site': 'phase04-test', 'projectId': fixture['projectId'],
        'scope': 'project', 'kind': 'Images', 'requestId': 'unauthorized-test-05', 'fileName': 'unauthorized.png',
        'mimeType': 'image/png', 'fileData': base64.b64encode((root / 'assets/fixtures/phase05/صورة-أفقية.png').read_bytes()).decode()}
checks = []
for name, identity in [('anonymous', ''), ('roleless', token)]:
    result = call(url, {**body, 'idToken': identity})
    assert result['success'] is False and result['error'] in ['authentication_required', 'upload_not_allowed', 'invalid_identity']
    checks.append({'actor': name, 'directUploadRejected': True, 'error': result['error']})
(root / 'phases/results/05/checks/upload-access.json').write_text(json.dumps({'checks': checks}, indent=2))
print(json.dumps({'directUploadDenials': len(checks)}))
