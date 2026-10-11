"""Authenticate privately and probe the live bridge. Never print credentials."""
import json
from pathlib import Path
import urllib.request
import urllib.error

root = Path(__file__).resolve().parent.parent
def load(name): return json.loads((root / name).read_text(encoding='utf-8'))
def post(url, body, content='application/json'):
    request = urllib.request.Request(url, data=json.dumps(body).encode(), headers={'Content-Type': content}, method='POST')
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read().decode('utf-8')
            try: return json.loads(raw)
            except ValueError: return {'success': False, 'error': 'non_json_response', 'requiresGoogleConsent': 'authorization' in raw.lower() or 'accounts.google.com' in raw.lower()}
    except urllib.error.HTTPError as error: return {'success': False, 'error': 'http_' + str(error.code)}

firebase = load('config/firebase.web.json')
identity = load('config/identity.phase04.json')
owner = load('.runtime/yogen-owner.local.json')
config = load('config/drive.phase05.json')
signed = post('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=' + firebase['FIREBASE_API_KEY'],
              {'email': identity['managerAuthEmail'], 'password': owner['password'], 'returnSecureToken': True})
if 'idToken' not in signed: raise SystemExit('Owner sign-in unavailable; no credential details emitted')
result = post(config['webAppUrl'], {'action': 'ping', 'site': 'phase04-test', 'idToken': signed['idToken']}, 'text/plain;charset=utf-8')
report = {key: result.get(key) for key in ['success', 'error', 'requiresGoogleConsent', 'version', 'maxBytes', 'rootFolderId'] if key in result}
(root / 'phases/results/05/checks/connection-probe.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report))
