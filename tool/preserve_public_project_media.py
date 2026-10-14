"""Preserve published Hosting images before rebuilding the site; no data writes."""
import concurrent.futures
import hashlib
import json
import pathlib
import re
import urllib.parse
import urllib.request

root = pathlib.Path(__file__).resolve().parents[1]
base = 'https://firestore.googleapis.com/v1/projects/portfolio-14d15/databases/(default)/documents'
def decode(v):
    for key in ['stringValue', 'booleanValue']:
        if key in v: return v[key]
    for key in ['integerValue', 'doubleValue']:
        if key in v: return float(v[key])
    if 'arrayValue' in v: return [decode(x) for x in v['arrayValue'].get('values', [])]
    if 'mapValue' in v: return {k: decode(x) for k, x in v['mapValue'].get('fields', {}).items()}
    return None
images = {}
cursor = None
while True:
    query = {'from': [{'collectionId': 'projects'}], 'limit': 24,
             'orderBy': [{'field': {'fieldPath': '__name__'}, 'direction': 'ASCENDING'}]}
    if cursor: query['startAt'] = {'before': False, 'values': [{'referenceValue': cursor}]}
    request = urllib.request.Request(base + '/sites/yogen:runQuery',
        data=json.dumps({'structuredQuery': query}).encode(), headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(request, timeout=45) as response: rows = json.load(response)
    docs = [row['document'] for row in rows if 'document' in row]
    for doc in docs:
        fields = {k: decode(v) for k, v in doc.get('fields', {}).items()}
        for asset in fields.get('assets', []):
            if asset.get('driveFileId') or not asset.get('publicUrl'): continue
            url = urllib.parse.urlparse(asset['publicUrl'])
            if url.scheme != 'https' or url.hostname != 'portfolio-14d15.web.app' or url.query or url.fragment:
                raise RuntimeError('Published image URL is outside this site.')
            if not re.fullmatch(r'/project-media/[a-f0-9]{64}\.(jpg|jpeg|png|webp)', url.path):
                raise RuntimeError('Published image path cannot be preserved safely.')
            images[url.path] = asset['publicUrl']
    if len(docs) < 24: break
    cursor = docs[-1]['name']

def preserve(item):
    path, url = item
    target = root / 'web' / path.lstrip('/')
    with urllib.request.urlopen(url, timeout=60) as response:
        data = response.read(5 * 1024 * 1024 + 1)
        if response.headers.get_content_type() not in ['image/jpeg', 'image/png', 'image/webp']:
            raise RuntimeError('Published media URL returned a non-image response.')
    if not data or len(data) > 5 * 1024 * 1024: raise RuntimeError('Published image exceeds media bounds.')
    signature = data.startswith(b'\xff\xd8\xff') or data.startswith(b'\x89PNG\r\n\x1a\n') or (data[:4] == b'RIFF' and data[8:12] == b'WEBP')
    if not signature: raise RuntimeError('Published media has no supported image signature.')
    if hashlib.sha256(data).hexdigest() != target.stem:
        raise RuntimeError('Published image does not match its immutable path hash.')
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and target.read_bytes() != data:
        raise RuntimeError('A different local image already uses this path; no overwrite performed.')
    target.write_bytes(data)
    return {'path': path, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}

with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    records = list(pool.map(preserve, images.items()))
directory = root / '.runtime/image-fix'
directory.mkdir(parents=True, exist_ok=True)
(directory / 'preserved-media.json').write_text(json.dumps(records, indent=2), encoding='utf-8')
print(json.dumps({'publishedImagesPreserved': len(records), 'bytes': sum(x['bytes'] for x in records),
                  'firestoreWrites': 0, 'driveWrites': 0}))
