"""Package already-built release artifacts. Does not run application tests."""
import hashlib
import json
import pathlib
import re
import shutil
import zipfile
from datetime import datetime, timezone

root = pathlib.Path(__file__).resolve().parents[1]
version, build_number = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', (root / 'pubspec.yaml').read_text(), re.M).groups()
release = root / 'releases' / version
web = release / 'web'
for source in (root / 'web/project-media').glob('*'):
    if source.is_file():
        target = web / 'project-media' / source.name
        if not target.exists() or target.read_bytes() != source.read_bytes():
            raise RuntimeError('A published image is missing or different in the web build.')
android = release / 'android'
android.mkdir(parents=True, exist_ok=True)
apk = root / 'build/app/outputs/flutter-apk/app-release.apk'
apk_metadata = json.loads((root / 'build/app/outputs/apk/release/output-metadata.json').read_text())['elements'][0]
if apk_metadata['versionName'] != version or apk_metadata['versionCode'] != int(build_number):
    raise RuntimeError('Android build metadata does not match the release being packaged.')
shutil.copy2(apk, android / f'yogen-{version}.apk')
(web / 'downloads').mkdir(exist_ok=True)
shutil.copy2(apk, web / 'downloads' / f'yogen-{version}.apk')
origin = 'https://portfolio-14d15.web.app'
index = (web / 'index.html').read_text(encoding='utf-8')
index = index.replace('content="noindex,nofollow"', 'content="index,follow"')
index = index.replace('content="sharing/yogen-logo.png"', 'content="' + origin + '/sharing/yogen-logo.png"')
if '<link rel="canonical"' not in index:
    index = index.replace('</head>', '<link rel="canonical" href="' + origin + '/">\n</head>')
(web / 'index.html').write_text(index, encoding='utf-8')
(web / 'robots.txt').write_text('User-agent: *\nAllow: /\nDisallow: /admin\nDisallow: /validation\nDisallow: /downloads/\nSitemap: ' + origin + '/sitemap.xml\n', encoding='utf-8')
(web / 'sitemap.xml').write_text('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>' + origin + '/</loc></url></urlset>\n', encoding='utf-8')

def digest(file):
    result = hashlib.sha256()
    with file.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()

with zipfile.ZipFile(release / f'yogen-{version}-web.zip', 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
    for file in sorted(web.rglob('*')):
        if file.is_file() and 'downloads' not in file.relative_to(web).parts:
            bundle.write(file, file.relative_to(web))

source_files = [
    'lib/app/yogen_app.dart', 'lib/core/page_metadata_web.dart',
    'lib/features/public/home_page.dart', 'lib/features/public/depth_scene.dart',
    'lib/features/public/logo_admin_entry.dart', 'lib/features/public/public_shell.dart',
    'lib/features/validation/scene_page.dart', 'lib/features/admin/access_pages.dart',
    'lib/features/admin/admin_shell.dart', 'lib/auth/account_auth.dart',
    'lib/core/viewport_visibility.dart', 'lib/features/media/media_preview.dart',
    'lib/features/media/media_transport.dart', 'lib/features/public/project_widgets.dart',
    'lib/features/public/public_pages.dart', 'lib/features/admin/project_editor_page.dart',
    'lib/features/admin/media_library_page.dart', 'lib/features/admin/projects_pages.dart',
    'pubspec.yaml', 'pubspec.lock', 'firebase.json', 'web/manifest.json',
    'web/flutter_bootstrap.js', 'android/app/build.gradle.kts',
    'android/app/src/main/res/drawable/yogen_launcher.xml', 'web/icons/yogen-mark.svg',
]
manifest = {
    'releaseId': f'yogen-{version}+{build_number}', 'projectId': 'portfolio-14d15', 'site': 'yogen',
    'packagedAt': datetime.now(timezone.utc).isoformat(), 'publicOrigin': origin,
    'testsExecuted': False, 'runtimeVerified': False,
    'sourceHashes': {p: digest(root / p) for p in source_files},
    'files': [{'path': str(p.relative_to(release)).replace('\\', '/'), 'bytes': p.stat().st_size,
               'sha256': digest(p)} for p in sorted(release.rglob('*')) if p.is_file() and p.name != 'release-manifest.json'],
}
(release / 'release-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(json.dumps({'releaseId': manifest['releaseId'], 'webPrepared': True, 'signedApkPackaged': True, 'applicationTestsRun': False}))
