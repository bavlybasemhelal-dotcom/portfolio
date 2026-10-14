"""Package the tested web build and original project pictures for Hosting."""
import hashlib
import json
import shutil
from pathlib import Path

root = Path(__file__).resolve().parent.parent
catalog_dir = root / 'content/company-projects'
catalog = json.loads((catalog_dir / 'projects.json').read_text(encoding='utf-8'))
web = root / 'releases/company-projects/web'
shutil.copytree(root / '.runtime/company-web-fix', web, dirs_exist_ok=True)
origin = 'https://portfolio-14d15.web.app'
index = (web / 'index.html').read_text(encoding='utf-8')
index = index.replace('content="noindex,nofollow"', 'content="index,follow"')
index = index.replace('content="sharing/yogen-logo.png"', 'content="' + origin + '/sharing/yogen-logo.png"')
if '<link rel="canonical"' not in index:
    index = index.replace('</head>', '<link rel="canonical" href="' + origin + '/">\n</head>')
(web / 'index.html').write_text(index, encoding='utf-8')
(web / 'robots.txt').write_text('User-agent: *\nAllow: /\nDisallow: /admin\nDisallow: /validation\nDisallow: /downloads/\nSitemap: ' + origin + '/sitemap.xml\n', encoding='utf-8')
(web / 'sitemap.xml').write_text('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>' + origin + '/</loc></url></urlset>\n', encoding='utf-8')
images = web / 'project-media'
images.mkdir(exist_ok=True)
for project in catalog['projects']:
    for media in project['media']:
        data = (catalog_dir / media['file']).read_bytes()
        assert hashlib.sha256(data).hexdigest() == media['sha256']
        (images / (media['sha256'] + '.jpg')).write_bytes(data)

rules = (root / '.runtime/company-import/deployed.rules').read_text(encoding='utf-8')
changes = [
    ("['id','driveFileId','name','mime','bytes','alt','thumbnailDriveFileId'])",
     "['id','driveFileId','name','mime','bytes','alt','thumbnailDriveFileId','publicUrl'])"),
    ("&& filled(v.id,70) && v.driveFileId is string && v.driveFileId.matches('[A-Za-z0-9_-]{10,200}')",
     "&& filled(v.id,70) && v.driveFileId is string\n"
     "        && (v.driveFileId.matches('[A-Za-z0-9_-]{10,200}') || (v.driveFileId == '' && 'publicUrl' in v))\n"
     "        && (!('publicUrl' in v) || (v.publicUrl is string && v.publicUrl.matches('https://portfolio-14d15[.]web[.]app/project-media/[a-f0-9]{64}[.]jpg')))"),
    ("&& v.public.thumbnailDriveFileId == r.thumbnailFileId",
     "&& v.public.thumbnailDriveFileId == r.thumbnailFileId\n"
     "            && (!('publicUrl' in v.public) || (r.get('storage','') == 'hosting'\n"
     "              && v.public.publicUrl == r.publicUrl\n"
     "              && r.publicUrl == 'https://portfolio-14d15.web.app/project-media/' + r.sha256 + '.jpg'))"),
]
for before, after in changes:
    if rules.count(before) == 1:
        rules = rules.replace(before, after)
    else:
        assert rules.count(after) == 1, before
(root / 'firebase/firestore.company-media.rules').write_text(rules, encoding='utf-8')

config = json.loads((root / 'firebase.json').read_text(encoding='utf-8'))
config['hosting']['public'] = web.relative_to(root).as_posix()
config['hosting']['headers'].append({'source': '/project-media/**', 'headers': [
    {'key': 'Cache-Control', 'value': 'public, max-age=31536000, immutable'},
    {'key': 'Access-Control-Allow-Origin', 'value': '*'},
]})
config['firestore'] = {'rules': 'firebase/firestore.company-media.rules'}
config['emulators'] = {'firestore': {'host': '127.0.0.1', 'port': 8085},
                       'ui': {'enabled': False}, 'singleProjectMode': True}
(root / 'firebase.company.json').write_text(json.dumps(config, indent=2), encoding='utf-8')
print(json.dumps({'web': str(web), 'images': len(list(images.glob('*.jpg'))),
                  'rulesDerivedFromDeployedVersion': True}))
