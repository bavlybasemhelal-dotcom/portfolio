"""Call the deployed bridge with an isolated user; never print ID tokens."""
import datetime
import json
import pathlib
import time
import urllib.request
import urllib.error
ROOT = pathlib.Path(__file__).resolve().parents[1]
config_path = ROOT / 'config/drive.phase03.json'
config = json.loads(config_path.read_text())
config['scriptId'] = '1lHvWFz6bmDMusHkTQa0UXJT83p_pM_f-nKt7JGJcq9QQuIG-wW3b28VV'
config['deploymentId'] = 'AKfycbwXEJ6WPVz2TM9emP4nBXzPz446HhcjzMobktEYfZdULceFrmUa-XTclubj3TBMBkX0Vg'
config['webAppUrl'] = 'https://script.google.com/macros/s/' + config['deploymentId'] + '/exec'
config['status'] = 'deployed_pending_runtime_verification'
config_path.write_text(json.dumps(config, indent=2))
user = json.loads((ROOT / '.runtime/firebase-test-user.local.json').read_text())
request = urllib.request.Request(config['webAppUrl'], method='POST',
    data=json.dumps({'action': 'ping', 'idToken': user['idToken']}).encode(),
    headers={'Content-Type': 'text/plain;charset=utf-8'})
report = {'date': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'test': 'real_bridge_ping'}
start = time.monotonic()
try:
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
        report.update(httpStatus=response.status, responseBytes=len(data), elapsedMs=round((time.monotonic()-start)*1000))
        try:
            result = json.loads(data)
            report.update(result=result, ok=result.get('success') is True)
        except ValueError:
            report.update(ok=False, error='non_json_runtime_response')
            (ROOT / '.runtime/bridge-runtime-response.local.html').write_bytes(data)
except urllib.error.HTTPError as error:
    data = error.read()
    (ROOT / '.runtime/bridge-runtime-response.local.html').write_bytes(data)
    report.update(ok=False, error='HTTPError', httpStatus=error.code,
        elapsedMs=round((time.monotonic()-start)*1000), responseBytes=len(data))
except Exception as error:
    report.update(ok=False, error=type(error).__name__, elapsedMs=round((time.monotonic()-start)*1000))
(ROOT / 'phases/results/03/checks/bridge-ping.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report, ensure_ascii=True))
