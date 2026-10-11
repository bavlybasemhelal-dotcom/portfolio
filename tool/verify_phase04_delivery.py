"""Check phase 4 handover, evidence, and public artifacts without exposing secrets."""
import hashlib
import json
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
CHECKS = ROOT / 'phases/results/04/checks'


def read_json(name):
    return json.loads((CHECKS / f'{name}.json').read_text(encoding='utf-8'))


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


docs = [ROOT / name for name in (
    'README.md', 'YOGEN-PORTFOLIO-PLAN.md', 'phases/README.md',
    'phases/STATUS.md', 'phases/04-DATA-AUTH-PERMISSIONS.md')]
docs += sorted((ROOT / 'phases/results/04').glob('*.md'))
broken = []
links = 0
for doc in docs:
    for target in re.findall(r'\]\(([^)]+)\)', doc.read_text(encoding='utf-8')):
        target = target.strip('<>')
        if re.match(r'^[A-Za-z]:[/\\]', target):
            links += 1
            target = re.sub(r':\d+$', '', target.split('#')[0])
            if not Path(target).exists():
                broken.append({'document': str(doc.relative_to(ROOT)), 'target': target})

ignored = {'.runtime', 'build', '.dart_tool', '.git', 'ephemeral',
           '.gradle', '__pycache__', 'node_modules', '.pub-cache'}
extensions = {'.md', '.json', '.js', '.cjs', '.mjs', '.dart', '.py',
              '.rules', '.yaml', '.txt', '.ps1', '.html'}
patterns = [r'ya29\.[A-Za-z0-9_-]{20,}', r'1//[A-Za-z0-9_-]{30,}',
            r'eyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}',
            r'-----BEGIN (?:RSA |EC )?PRIVATE KEY-----']
findings = []
scanned = 0
for directory, children, files in os.walk(ROOT):
    children[:] = [name for name in children if name not in ignored]
    for name in files:
        file = Path(directory) / name
        if (name.endswith('.local.json') or file.suffix not in extensions
                or name in {'firebase-debug.log', 'firestore-debug.log', 'ui-debug.log'}):
            continue
        content = file.read_text(encoding='utf-8', errors='replace')
        scanned += 1
        if any(re.search(pattern, content) for pattern in patterns):
            findings.append(str(file.relative_to(ROOT)))  # Never include matched secrets.

evidence = {}
for name, expected in [('rules-emulator', 20), ('dart-rest-emulator', 2),
                       ('dart-rest-cloud', 3), ('browser-cloud', 12), ('final-browser', 5)]:
    data = read_json(name)
    checks = data.get('checks', [])
    evidence[name] = {'checks': len(checks), 'expected': expected,
                      'ok': len(checks) == expected and all(c.get('ok') is True for c in checks)
                      and not data.get('errors')}

bootstrap = read_json('owner-bootstrap')
deployed = read_json('deployed-rules')
recovery = read_json('recovery-cloud')
cleanup = read_json('fixtures-cleanup')
flutter_log = (CHECKS / 'flutter-tests.txt').read_text(encoding='utf-8')
analyze_log = (CHECKS / 'analyze.txt').read_text(encoding='utf-8')
delivery_checks = {
    'strictRulesRestored': bootstrap.get('strictRulesRestored') is True,
    'deployedRulesMatchStrictPhase04': deployed.get('matchesStrictPhase04') is True,
    'recoverySameUidAndNoEmail': all(recovery.get(k) is True for k in (
        'sameUid', 'oldPasswordRejected', 'newPasswordWorks', 'noEmailSent', 'stdinOnly')),
    'testAccountsCleanedOwnerPreserved': cleanup.get('ownerPreserved') is True
        and cleanup.get('publicTestProjectsRemaining') == 0
        and cleanup.get('disabledTestRoles') == 10 and cleanup.get('deletedTestAuth') == 10,
    'flutter29Passed4IntentionalSkipped': '+29 ~4: All tests passed!' in flutter_log,
    'analysisClean': 'No issues found!' in analyze_log,
    'finalBrowserUsesYogen': read_json('final-browser').get('site') == 'yogen',
    'windowsDeferredByUser': 'بطلب المستخدم' in (ROOT / 'phases/results/04/REPORT.md').read_text(encoding='utf-8'),
    'phase5NotStarted': '| 5 | لم تبدأ |' in (ROOT / 'phases/STATUS.md').read_text(encoding='utf-8'),
}
for name, marker in [('web', 'Built build\\web'), ('android', 'app-debug.apk')]:
    delivery_checks[f'{name}BuildCompleted'] = marker in (CHECKS / f'build-{name}.txt').read_text(encoding='utf-8')

artifacts = []
for name in ['build/web/main.dart.js', 'build/app/outputs/flutter-apk/app-debug.apk']:
    file = ROOT / name
    if not file.exists():
        delivery_checks[f'artifact:{name}'] = False
        continue
    artifacts.append({'path': name, 'bytes': file.stat().st_size, 'sha256': sha256(file)})

ok = (not broken and not findings and all(c['ok'] for c in evidence.values())
      and all(delivery_checks.values()) and len(artifacts) == 2)
result = {'ok': ok, 'localLinksChecked': links, 'brokenLinks': broken,
          'publicTextFilesScanned': scanned, 'credentialPatternPaths': findings,
          'evidence': evidence, 'deliveryChecks': delivery_checks,
          'buildArtifacts': artifacts, 'windows': 'Deferred by explicit user request; excluded'}
(CHECKS / 'delivery-validation.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps({'ok': ok, 'links': links, 'broken': len(broken), 'credentialPatternPaths': findings,
                  'deliveryChecks': delivery_checks, 'buildArtifacts': len(artifacts)}))
if not ok:
    raise SystemExit(1)
