"""Check public Firestore documents against the prepared catalogue, read-only."""
import json
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'content/company-projects'
catalog = json.loads((OUT / 'projects.json').read_text(encoding='utf-8'))
base = ('https://firestore.googleapis.com/v1/projects/portfolio-14d15/'
        'databases/(default)/documents/sites/yogen/projects')


def decode(value):
    for key, item in value.items():
        if key == 'mapValue':
            return {k: decode(v) for k, v in item.get('fields', {}).items()}
        if key == 'arrayValue':
            return [decode(v) for v in item.get('values', [])]
        if key == 'integerValue':
            return int(item)
        return item


documents = {}
url = base + '?pageSize=100'
while url:
    with urlopen(url, timeout=30) as response:
        page = json.load(response)
    for doc in page.get('documents', []):
        documents[doc['name'].rsplit('/', 1)[1]] = {
            k: decode(v) for k, v in doc['fields'].items()
        }
    token = page.get('nextPageToken')
    if token:
        from urllib.parse import quote
        url = base + '?pageSize=100&pageToken=' + quote(token)
    else:
        url = None

results = []
for project in catalog['projects']:
    public = documents.get(project['projectId'])
    if not public:
        results.append({'projectId': project['projectId'], 'published': False})
        continue
    expected = project['content']
    content = public['content']
    keys = ['title', 'summary', 'body', 'contribution', 'categoryId', 'slug',
            'usage', 'attribution', 'order', 'year']
    errors = [key for key in keys if content.get(key) != expected.get(key)]
    assets = public.get('assets', [])
    if content.get('mediaIds') != [asset['id'] for asset in assets]:
        errors.append('media_reference_order')
    if len(assets) != len(project['media']):
        errors.append('asset_count')
    for media, asset in zip(project['media'], assets):
        if (Path(media['file']).name != asset.get('name') or
                media['alt'] != asset.get('alt') or
                media['bytes'] != asset.get('bytes') or
                asset.get('mime') != 'image/jpeg'):
            errors.append(media['file'])
    results.append({'projectId': project['projectId'], 'published': True,
                    'contentAndMediaMatch': not errors, 'mismatches': errors,
                    'imageCount': len(assets), 'revision': public['revision']})

report = {'checkedAt': datetime.now(timezone.utc).isoformat(),
          'expectedProjects': len(catalog['projects']),
          'publishedProjects': sum(r['published'] for r in results),
          'publishedImages': sum(r.get('imageCount', 0) for r in results),
          'allPublishedContentMatches': all(r.get('contentAndMediaMatch', True)
                                           for r in results),
          'complete': all(r['published'] and r['contentAndMediaMatch']
                          for r in results),
          'projects': results}
(OUT / 'publication/public-readback.json').write_text(
    json.dumps({'report': report, 'documents': documents}, ensure_ascii=False,
               indent=2), encoding='utf-8')
(OUT / 'publication-verification.json').write_text(
    json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
status_file = OUT / 'publish-status.json'
status = json.loads(status_file.read_text(encoding='utf-8'))
status['publishedProjectIds'] = [r['projectId'] for r in results if r['published']]
status['publicReadback'] = report
if report['complete']:
    status['status'] = 'published'
else:
    status['status'] = 'incomplete'
status_file.write_text(json.dumps(status, ensure_ascii=False, indent=2),
                       encoding='utf-8')
print(json.dumps({k: v for k, v in report.items() if k != 'projects'}))
