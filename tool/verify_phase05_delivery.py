"""Verify phase 5 handover, evidence and public sources without exposing secrets."""
import hashlib
import json
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
CHECKS = ROOT / 'phases/results/05/checks'


def read_json(name):
    return json.loads((CHECKS / f'{name}.json').read_text(encoding='utf-8'))


def sha256(file):
    digest = hashlib.sha256()
    with file.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


docs = [ROOT / name for name in (
    'README.md', 'YOGEN-PORTFOLIO-PLAN.md', 'phases/README.md',
    'phases/STATUS.md', 'phases/05-DRIVE-MEDIA.md')]
docs += sorted((ROOT / 'phases/results/05').glob('*.md'))
broken, links = [], 0
for doc in docs:
    for target in re.findall(r'\]\(([^)]+)\)', doc.read_text(encoding='utf-8')):
        target = target.strip('<>')
        if re.match(r'^[A-Za-z]:[/\\]', target):
            links += 1
            target = re.sub(r':\d+$', '', target.split('#')[0])
            if not Path(target).exists():
                broken.append({'document': str(doc.relative_to(ROOT)), 'target': target})

ignored = {'.runtime', 'build', '.dart_tool', '.git', 'ephemeral', '.gradle',
           '__pycache__', 'node_modules', '.pub-cache'}
extensions = {'.md', '.json', '.js', '.cjs', '.mjs', '.dart', '.py', '.rules',
              '.yaml', '.txt', '.ps1', '.html'}
patterns = [r'ya29\.[A-Za-z0-9_-]{20,}', r'1//[A-Za-z0-9_-]{30,}',
            r'eyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}',
            r'-----BEGIN (?:RSA |EC )?PRIVATE KEY-----']
findings, scanned = [], 0
for directory, children, files in os.walk(ROOT):
    children[:] = [name for name in children if name not in ignored]
    for name in files:
        file = Path(directory) / name
        if (name.endswith('.local.json') or file.suffix not in extensions
                or name in {'firebase-debug.log', 'firestore-debug.log', 'ui-debug.log'}):
            continue
        scanned += 1
        content = file.read_text(encoding='utf-8', errors='replace')
        if any(re.search(pattern, content) for pattern in patterns):
            findings.append(str(file.relative_to(ROOT)))

evidence = {}
for name, expected in [('script-contract', 8), ('rules-emulator', 10),
                       ('dart-rest-cloud', 14), ('browser-public', 32),
                       ('browser-admin', 7), ('browser-upload-readback', 3), ('final-browser', 4)]:
    data = read_json(name)
    checks = data.get('checks', [])
    evidence[name] = {'checks': len(checks), 'expected': expected,
                      'ok': len(checks) == expected and all(c.get('ok') is True for c in checks)
                      and not data.get('errors')}

cloud, deploy = read_json('dart-rest-cloud'), read_json('script-deployment')
deployed, cleanup = read_json('deployed-rules'), read_json('fixtures-cleanup')
owner, upload = read_json('owner-connection'), read_json('upload-access')
flutter_log = (CHECKS / 'flutter-tests-sequential.txt').read_text(encoding='utf-8')
delivery_checks = {
    'cloudComplete': cloud.get('complete') is True,
    'scriptVersionSourceReadbackVerified': deploy.get('versionSourceReadbackVerified') is True,
    'oldDeploymentPreserved': bool(deploy.get('previousDeploymentPreserved')),
    'strictRulesDeployed': deployed.get('matchesStrictPhase05') is True
        and deployed.get('localHash') == hashlib.sha256(
            (ROOT / 'firebase/firestore.phase05.rules').read_text(encoding='utf-8')
            .replace('\r\n', '\n').strip().encode()).hexdigest(),
    'ownerConnectionSavedWithoutInventedEmail': owner.get('site') == 'yogen'
        and all(owner.get(k) is True for k in ('managerConnectionVerified',
                'privateSettingsSaved', 'publicRoutingSaved', 'administrativeEmailDeferred')),
    'directAnonymousAndRolelessUploadsRejected': len(upload.get('checks', [])) == 2
        and all(c.get('directUploadRejected') is True for c in upload['checks']),
    'testIdentitiesCleanedOwnerPreserved': cleanup.get('ownerPreserved') is True
        and cleanup.get('disabledTestRoles') == 1 and cleanup.get('deletedTemporaryAuth') == 2
        and cleanup.get('realTeamAccountsCreated') == 0,
    'flutter55Passed5IntentionalSkipped': '+55 ~5: All tests passed!' in flutter_log,
    'thumbnail6Passed': '+6: All tests passed!' in
        (CHECKS / 'thumbnail-tests.txt').read_text(encoding='utf-8'),
    'analysisClean': 'No issues found!' in (CHECKS / 'analyze.txt').read_text(encoding='utf-8'),
    'finalBrowserUsesYogen': read_json('final-browser').get('site') == 'yogen',
    'phase6NotStarted': '| 6 | لم تبدأ |' in (ROOT / 'phases/STATUS.md').read_text(encoding='utf-8'),
}
for name, marker in [('web', 'Built build\\web'), ('android', 'app-debug.apk')]:
    delivery_checks[f'{name}BuildCompleted'] = marker in (
        CHECKS / f'build-{name}.txt').read_text(encoding='utf-8')

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
          'evidence': evidence, 'deliveryChecks': delivery_checks, 'buildArtifacts': artifacts,
          'windows': 'Deferred by explicit user request; excluded',
          'physicalDevices': 'P05-T10 physical second device deferred to phase 9 by explicit user instruction; Android build and independent sessions only',
          'phase6': 'Not started; explicit user instruction required'}
(CHECKS / 'delivery-validation.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps({'ok': ok, 'links': links, 'broken': len(broken),
                  'credentialPatternPaths': findings, 'deliveryChecks': delivery_checks,
                  'buildArtifacts': len(artifacts)}))
if not ok:
    raise SystemExit(1)
