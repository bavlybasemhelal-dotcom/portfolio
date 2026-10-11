"""Verify saved evidence and public handover; output hashes, never credentials."""
import hashlib
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
out = root / 'phases/results/06'
checks = out / 'checks'
report = {'checks': [], 'reports': {}, 'artifacts': {}, 'errors': []}

def expect(name, condition):
    report['checks'].append({'name': name, 'ok': bool(condition)})
    if not condition:
        report['errors'].append(name)

for name in ['browser-public', 'browser-matrix', 'browser-routes',
             'browser-keyboard', 'browser-live-company', 'final-browser',
             'cloud-initial', 'rules-emulator', 'deployed-rules']:
    data = json.loads((checks / f'{name}.json').read_text(encoding='utf-8-sig'))
    expect(f'{name} no failed checks or errors',
           not data.get('errors') and all(v.get('ok') for v in data.get('checks', [])))
    if name not in ['rules-emulator', 'deployed-rules']:
        expect(f'{name} completed', data.get('complete') is True)
    report['reports'][name] = {
        'checks': len(data.get('checks', [])),
        'layouts': len(data.get('matrix', [])),
        'routes': len(data.get('routes', [])),
    }
    if name == 'browser-matrix':
        expect('72 browser layouts captured', len(data['matrix']) == 72 and all(v['ok'] for v in data['matrix']))
    if name == 'browser-routes':
        expect('6 direct routes survive reload', len(data['routes']) == 6)
    if name == 'deployed-rules':
        expect('Local and deployed rules match', data['matchesStrictPhase06'] and data['localHash'] == data['deployedHash'])

for name, marker in [('flutter-all-final.txt', '+75 ~6: All tests passed!'),
                     ('analyze-final.txt', 'No issues found!'),
                     ('build-web-final.txt', 'Built build'),
                     ('build-web-test-final.txt', 'Built build'),
                     ('build-android-final.txt', 'Built build')]:
    expect(name + ' succeeded', marker in (checks / name).read_text(encoding='utf-8-sig'))

for relative in ['build/web/main.dart.js', '.runtime/phase06-test-web/main.dart.js',
                 '.runtime/phase06-release-web/main.dart.js',
                 'build/app/outputs/flutter-apk/app-debug.apk',
                 'firebase/firestore.phase06.rules', 'lib/data/public_content_repository.dart']:
    source = root / relative
    payload = source.read_bytes()
    report['artifacts'][relative] = {'bytes': len(payload), 'sha256': hashlib.sha256(payload).hexdigest()}
expect('Saved public Web equals the delivered build',
       report['artifacts']['build/web/main.dart.js']['sha256'] ==
       report['artifacts']['.runtime/phase06-release-web/main.dart.js']['sha256'])

documents = [out/'REPORT.md', out/'TEST-RESULTS.md', out/'HANDOVER.md',
             root/'README.md', root/'phases/README.md', root/'phases/STATUS.md',
             root/'YOGEN-PORTFOLIO-PLAN.md']
missing = []
for document in documents:
    text = document.read_text(encoding='utf-8-sig')
    for target in re.findall(r'\]\((D:/[^)]+)\)', text):
        if not Path(target).exists() and Path(target).resolve() != (checks/'delivery-manifest.json').resolve():
            missing.append({'document': str(document.relative_to(root)), 'target': target})
expect('Local Markdown handover links resolve', not missing)
report['missingLinks'] = missing
report['complete'] = not report['errors']
(checks/'delivery-manifest.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'complete': report['complete'], 'checks': len(report['checks']), 'errors': report['errors']}, ensure_ascii=False))
raise SystemExit(0 if report['complete'] else 1)
