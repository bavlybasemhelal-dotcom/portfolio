"""Read-only public API probe; reports status only, never document contents."""
import concurrent.futures
import json
import pathlib
import urllib.error
import urllib.request

base = 'https://firestore.googleapis.com/v1/projects/portfolio-14d15/databases/(default)/documents'
checks = [
    ('published projects query', '/sites/yogen:runQuery', {
        'structuredQuery': {'from': [{'collectionId': 'projects'}],
                            'orderBy': [{'field': {'fieldPath': 'content.order'}, 'direction': 'ASCENDING'},
                                        {'field': {'fieldPath': '__name__'}, 'direction': 'ASCENDING'}],
                            'limit': 24}}),
    ('company public document', '/sites/yogen/company/current', None),
    ('team public collection', '/sites/yogen/team?pageSize=100', None),
    ('public media routing', '/sites/yogen/mediaRouting/current', None),
]


def probe(item):
    label, suffix, body = item
    request = urllib.request.Request(
        base + suffix, data=json.dumps(body).encode() if body is not None else None,
        headers={'Content-Type': 'application/json'}, method='POST' if body is not None else 'GET')
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            data = json.loads(response.read())
            return {'name': label, 'status': response.status, 'ok': response.status == 200,
                    'hasDocument': bool(data.get('name')) if isinstance(data, dict) else None}
    except urllib.error.HTTPError as error:
        value = json.loads(error.read())
        return {'name': label, 'status': error.code, 'ok': False,
                'error': value.get('error', {}).get('status', 'unknown')}
    except Exception as error:
        return {'name': label, 'ok': False, 'errorType': type(error).__name__}


with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
    results = list(executor.map(probe, checks))
report = {'scope': 'Anonymous REST reads, no document contents recorded', 'checks': results}
pathlib.Path('phases/results/08/checks/public-api-reads.json').write_text(
    json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report))
