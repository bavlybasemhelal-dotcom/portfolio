"""Verify handover links and that public text artifacts contain no live tokens."""
import hashlib
import json
import pathlib
import re

root = pathlib.Path(__file__).resolve().parent.parent
report_dir = root / 'phases/results/03/checks'
docs = [root / name for name in ['README.md', 'YOGEN-PORTFOLIO-PLAN.md',
        'phases/README.md', 'phases/STATUS.md', 'google_drive_script/README.md']]
docs += sorted((root / 'phases/results/03').glob('*.md'))
broken = []
links = 0
for doc in docs:
    for target in re.findall(r'\]\(([^)]+)\)', doc.read_text(encoding='utf-8')):
        target = target.strip('<>')
        if re.match(r'^[A-Za-z]:[/\\]', target):
            links += 1
            target = re.sub(r':\d+$', '', target.split('#')[0])
            if not pathlib.Path(target).exists():
                broken.append({'document': str(doc.relative_to(root)), 'target': target})

ignored = {'build', '.runtime', '.dart_tool', '.git', 'ephemeral', '.gradle', '__pycache__'}
extensions = {'.md', '.json', '.js', '.cjs', '.mjs', '.dart', '.py', '.rules', '.yaml', '.txt'}
patterns = [r'ya29\.[A-Za-z0-9_-]{20,}', r'1//[A-Za-z0-9_-]{30,}',
            r'eyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}',
            r'-----BEGIN (?:RSA |EC )?PRIVATE KEY-----']
findings = []
scanned = 0
for file in root.rglob('*'):
    relative = file.relative_to(root)
    if any(part in ignored for part in relative.parts) or not file.is_file():
        continue
    if file.name.endswith('.local.json') or file.suffix not in extensions:
        continue
    content = file.read_text(encoding='utf-8', errors='replace')
    scanned += 1
    if any(re.search(pattern, content) for pattern in patterns):
        findings.append(str(relative))  # Paths only; never print a credential match.

evidence = {}
for name in ['browser-smoke', 'media-browser', 'video-browser', 'script-contract',
             'permissions-cloud', 'performance-gzip']:
    data = json.loads((report_dir / f'{name}.json').read_text(encoding='utf-8'))
    checks = data.get('checks', [])
    evidence[name] = {'checks': len(checks), 'failedChecks': sum(c.get('ok') is False for c in checks),
                      'errors': len(data.get('errors', []))}

artifacts = []
for name in ['build/web/main.dart.js', 'build/windows/x64/runner/Release/yogen_portfolio.exe',
             'build/app/outputs/flutter-apk/app-debug.apk']:
    file = root / name
    if not file.exists():
        raise RuntimeError(f'Missing build artifact: {name}')
    digest = hashlib.sha256()
    with file.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    artifacts.append({'path': name, 'bytes': file.stat().st_size, 'sha256': digest.hexdigest()})

result = {'localLinksChecked': links, 'brokenLinks': broken, 'publicTextFilesScanned': scanned,
          'credentialPatternPaths': findings, 'evidence': evidence, 'buildArtifacts': artifacts}
(report_dir / 'delivery-validation.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps({'links': links, 'broken': len(broken), 'credentialPatternPaths': findings,
                  'buildArtifacts': len(artifacts), 'evidence': evidence}))
if broken or findings or any(v['failedChecks'] or v['errors'] for v in evidence.values()):
    raise SystemExit(1)
