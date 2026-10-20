"""Prepare an existing versioned web build; never build or deploy the app."""
import hashlib
import json
from pathlib import Path
from release_paths import release_identity, sync_hosting_paths, web_release_dir

root = Path(__file__).resolve().parent.parent
catalog_dir = root / 'content/company-projects'
catalog = json.loads((catalog_dir / 'projects.json').read_text(encoding='utf-8'))
web = web_release_dir(root)
version, build_number = release_identity(root)
if not (web / 'index.html').is_file() or not (web / 'version.json').is_file():
    raise RuntimeError('Build the current web release before preparing Hosting files.')
metadata = json.loads((web / 'version.json').read_text(encoding='utf-8'))
if metadata['version'] != version or int(metadata['build_number']) != build_number:
    raise RuntimeError('Web build version does not match pubspec.yaml.')
# The Flutter build must already contain every public image, including team
# photos. Never regenerate security rules from a private, possibly stale backup.
for source in (root / 'web/project-media').glob('*'):
    if source.is_file():
        target = web / 'project-media' / source.name
        if not target.is_file() or target.read_bytes() != source.read_bytes():
            raise RuntimeError('A public image is missing or different in the web build.')
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

sync_hosting_paths(root)
print(json.dumps({'web': str(web), 'images': len(list(images.glob('*.jpg'))),
                  'rulesPreserved': True, 'built': False, 'deployed': False}))
