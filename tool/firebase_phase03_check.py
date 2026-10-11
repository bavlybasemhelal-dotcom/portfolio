"""Isolated Auth + Firestore REST evidence. Credentials never enter reports."""
import datetime
import json
import pathlib
import secrets
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
private = ROOT / '.runtime/firebase-test-user.local.json'
config = json.loads((ROOT / 'config/firebase.web.json').read_text())
key = config['FIREBASE_API_KEY']

def call(url, data, token=None, method='POST'):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    request = urllib.request.Request(url, data=json.dumps(data).encode() if data is not None else None,
                                    headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=25) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, json.load(error)

report = {'date': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'projectId': 'portfolio-14d15',
          'transport': 'Google official REST APIs, not yet Flutter SDK evidence', 'checks': []}
user = json.loads(private.read_text()) if private.exists() else {
    'email': 'phase03-' + secrets.token_hex(6) + '@example.invalid', 'password': secrets.token_urlsafe(28)}
action = 'signInWithPassword' if private.exists() else 'signUp'
start = time.monotonic()
status, value = call('https://identitytoolkit.googleapis.com/v1/accounts:' + action + '?key=' + key,
                     dict(email=user['email'], password=user['password'], returnSecureToken=True))
report['checks'].append({'name': 'email_password_auth', 'httpStatus': status, 'ok': status == 200,
                         'elapsedMs': round((time.monotonic() - start) * 1000),
                         'error': value.get('error', {}).get('message') if status != 200 else None})
if status == 200:
    user.update(uid=value['localId'], idToken=value['idToken'], refreshToken=value['refreshToken'])
    private.write_text(json.dumps(user, indent=2), encoding='utf-8')
    token = value['idToken']
    run = str(time.time_ns())
    path = 'phase03_checks/' + user['uid'] + '/runs/' + run
    url = 'https://firestore.googleapis.com/v1/projects/portfolio-14d15/databases/(default)/documents/' + path
    fields = {'projectId': {'stringValue': 'portfolio-14d15'}, 'testOnly': {'booleanValue': True},
              'runId': {'stringValue': run}}
    status, value = call(url, {'fields': fields}, token, 'PATCH')
    report['checks'].append({'name': 'firestore_write', 'httpStatus': status, 'ok': status == 200,
        'error': value.get('error', {}).get('status') if status != 200 else None})
    if status == 200:
        status, value = call(url, None, token, 'GET')
        report['checks'].append({'name': 'firestore_server_read', 'httpStatus': status,
            'ok': status == 200 and value.get('fields') == fields, 'path': path})
(ROOT / 'phases/results/03/checks/firebase-rest.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=True))
