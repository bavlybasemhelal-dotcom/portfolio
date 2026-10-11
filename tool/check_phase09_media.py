"""Read published fixture media without changing Drive or Firestore."""
import base64
import hashlib
import json
import pathlib
import time
import urllib.request

root = pathlib.Path(__file__).resolve().parents[1]
config = json.loads((root / 'config/drive.phase05.json').read_text(encoding='utf-8'))
fixture = json.loads((root / 'phases/results/09/checks/device-republished.json').read_text(encoding='utf-8'))
results = []
for asset in fixture['mediaIds'][:3]:
    for thumbnail in [True, False]:
        body = json.dumps({'action': 'read', 'site': 'phase04-test',
                           'assetId': asset, 'thumbnail': thumbnail}).encode()
        request = urllib.request.Request(config['DRIVE_WEB_APP_URL'], data=body,
                                         headers={'Content-Type': 'application/json'})
        started = time.perf_counter()
        with urllib.request.urlopen(request, timeout=45) as response:
            data = json.load(response)
        if data.get('success') is not True:
            raise RuntimeError(data.get('error', 'invalid_response'))
        raw = base64.b64decode(data['fileData'], validate=True)
        assert len(raw) == data['fileSize']
        assert data['mimeType'].startswith('image/')
        results.append({'assetId': asset, 'thumbnail': thumbnail,
                        'bytes': len(raw), 'mimeType': data['mimeType'],
                        'durationMs': round((time.perf_counter() - started) * 1000, 2),
                        'sha256': hashlib.sha256(raw).hexdigest(),
                        'withinBudget': len(raw) <= (200 * 1024 if thumbnail else 1024 * 1024)})
out = root / 'phases/results/09/checks/drive-read.json'
out.write_text(json.dumps(results, indent=2), encoding='utf-8')
print(json.dumps({'reads': len(results), 'budgetsPassed': all(x['withinBudget'] for x in results)}))
