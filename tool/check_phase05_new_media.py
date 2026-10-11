"""Read back the actual browser uploads and generated thumbnails, without login output."""
import base64
import hashlib
import io
import json
from pathlib import Path
import urllib.request
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
CHECKS = ROOT / 'phases/results/05/checks'


def request(url, body=None, token=None):
    headers = {'Content-Type': 'text/plain' if 'script.google.com' in url else 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(url, data=None if body is None else json.dumps(body).encode(), headers=headers)
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.load(response)


def value(v):
    if 'mapValue' in v:
        return {k: value(n) for k, n in v['mapValue'].get('fields', {}).items()}
    if 'integerValue' in v:
        return int(v['integerValue'])
    for k in ('stringValue', 'booleanValue', 'timestampValue'):
        if k in v:
            return v[k]
    return None


owner = json.loads((ROOT / '.runtime/yogen-owner.local.json').read_text())
key = json.loads((ROOT / 'config/firebase.web.json').read_text())['FIREBASE_API_KEY']
drive = json.loads((ROOT / 'config/drive.phase05.json').read_text())
token = request('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=' + key,
                {'email': owner['email'], 'password': owner['password'], 'returnSecureToken': True})['idToken']
collection = 'https://firestore.googleapis.com/v1/projects/portfolio-14d15/databases/(default)/documents/sites/phase04-test/media?pageSize=100'
documents = request(collection, token=token).get('documents', [])
media = [{k: value(v) for k, v in d['fields'].items()} for d in documents]
media = [m for m in media if m['public']['alt']['en'].startswith('Browser upload test image')]
checks = []
for name, expected_size in [('صورة-أفقية.png', (320, 180)), ('صورة-رأسية.jpg', (320, 569)), ('صورة-ويب.webp', (320, 240))]:
    found = sorted([m for m in media if m['public']['name'] == name], key=lambda m: m['createdAt'])[-1]
    original = request(drive['webAppUrl'], {'action': 'read', 'site': 'phase04-test', 'assetId': found['public']['id']})
    thumb = request(drive['webAppUrl'], {'action': 'read', 'site': 'phase04-test', 'assetId': found['public']['id'], 'thumbnail': True})
    assert original['success'] and thumb['success']
    original_bytes = base64.b64decode(original['fileData'])
    thumbnail_bytes = base64.b64decode(thumb['fileData'])
    digest = hashlib.sha256(original_bytes).hexdigest()
    with Image.open(io.BytesIO(thumbnail_bytes)) as image:
        size = image.size
        image.load()
        assert image.format == 'PNG' and size[0] == expected_size[0] and abs(size[1] - expected_size[1]) <= 1
    assert len(thumbnail_bytes) <= 200 * 1024 and found['ready'] is True and found['verified'] is True
    assert original_bytes == (ROOT / 'assets/fixtures/phase05' / name).read_bytes()
    assert found['source']['sha256'] == digest and original['fileId'] == found['public']['driveFileId']
    assert thumb['fileId'] == found['public']['thumbnailDriveFileId']
    checks.append({'name': name + ' actual browser upload and anonymous PNG thumbnail readback', 'ok': True,
                   'assetId': found['public']['id'], 'originalSha256': digest,
                   'thumbnailPixels': size, 'thumbnailBytes': len(thumbnail_bytes)})
result = {'environment': 'Actual Flutter browser-generated files read from Drive; original bytes match local fixtures', 'checks': checks}
(CHECKS / 'browser-upload-readback.json').write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps({'passed': len(checks), 'allOriginalsMatch': True, 'allThumbnailsDecode': True}))
