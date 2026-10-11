"""Real bridge probes; public fixtures only. Never emit ID tokens."""
import base64
import datetime
import json
import pathlib
import struct
import time
import urllib.error
import urllib.request
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
config = json.loads((ROOT / 'config/drive.phase03.json').read_text())
user = json.loads((ROOT / '.runtime/firebase-test-user.local.json').read_text())
report = {'date': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'transport': 'real Apps Script + Drive + Firestore REST', 'checks': []}

def request(body):
    start = time.monotonic()
    req = urllib.request.Request(config['webAppUrl'], data=json.dumps(body, ensure_ascii=False).encode('utf-8'),
        headers={'Content-Type': 'text/plain;charset=utf-8'}, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=70) as response:
            result = json.load(response)
            return result, round((time.monotonic()-start)*1000)
    except urllib.error.HTTPError as error:
        return {'success': False, 'error': 'http_' + str(error.code)}, round((time.monotonic()-start)*1000)

def image_fixture():
    width, height = 800, 450
    data = bytearray()
    for y in range(height):
        data.append(0)
        for x in range(width):
            data.extend((15+(x*40//width), 80+(y*130//height), 160+(x*90//width)))
    def chunk(kind, content):
        return struct.pack('>I',len(content)) + kind + content + struct.pack('>I',zlib.crc32(kind+content) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,2,0,0,0)) + chunk(b'IDAT',zlib.compress(data)) + chunk(b'IEND',b'')
    folder = ROOT / 'assets/fixtures'
    folder.mkdir(exist_ok=True)
    (folder / 'phase03-test.png').write_bytes(png)
    return png

def record_file(value, run):
    fields = {key: {'integerValue': str(val)} if isinstance(val, int) else {'stringValue': val}
              for key,val in value.items() if key in ['fileId','fileName','fileSize','mimeType','directUrl','viewUrl','downloadUrl']}
    fields['testOnly'] = {'booleanValue': True}
    url = 'https://firestore.googleapis.com/v1/projects/portfolio-14d15/databases/(default)/documents/phase03_checks/' + user['uid'] + '/media/' + run
    req = urllib.request.Request(url, data=json.dumps({'fields':fields}).encode(),
        headers={'Authorization':'Bearer ' + user['idToken'],'Content-Type':'application/json'}, method='PATCH')
    with urllib.request.urlopen(req,timeout=25) as response:
        return response.status == 200

for label, body, expected in [('anonymous_upload_rejected', {'action':'upload'}, 'authentication_required'),
                              ('invalid_token_rejected', {'action':'ping','idToken':'invalid'}, 'authentication_required')]:
    value, elapsed = request(body)
    report['checks'].append({'name':label,'ok':value.get('error') == expected,'elapsedMs':elapsed,'response':value})
    print(json.dumps(report['checks'][-1]))

png = image_fixture()
run = 'phase03-image-20261009'
body = {'action':'upload','category':'phase03','idToken':user['idToken'],'fileName':'YOGEN-صورة-اختبار.png',
        'mimeType':'image/png','fileData':base64.b64encode(png).decode(),'requestId':run}
value, elapsed = request(body)
report['checks'].append({'name':'arabic_image_upload','ok':value.get('success') is True,'bytes':len(png),'elapsedMs':elapsed,'response':value})
print(json.dumps(report['checks'][-1],ensure_ascii=True))
if value.get('success'):
    config['publicTestImageId'] = value['fileId']; config['status'] = 'bridge_and_image_rest_verified_pending_flutter'
    (ROOT / 'config/drive.phase03.json').write_text(json.dumps(config,indent=2))
    saved = record_file(value,run)
    report['checks'].append({'name':'firestore_media_metadata','ok':saved})
    again, duration = request(body)
    report['checks'].append({'name':'retry_avoids_duplicate','ok':again.get('fileId') == value['fileId'],'elapsedMs':duration})
    anonymous, duration = request({'action':'image','fileId':value['fileId']})
    decoded = base64.b64decode(anonymous.get('fileData',''))
    report['checks'].append({'name':'anonymous_image_bytes','ok':decoded == png,'bytes':len(decoded),'elapsedMs':duration})
    print(json.dumps(report['checks'][-1]))

source = ROOT / '.runtime/video-source.mp4'
if source.exists():
    video = source.read_bytes()
    target = 5*1024*1024
    padded = video + struct.pack('>I4s', target-len(video), b'free') + bytes(target-len(video)-8)
    (ROOT / '.runtime/video-5MiB.mp4').write_bytes(padded)
    value,duration = request({'action':'upload','category':'phase03','idToken':user['idToken'],
       'fileName':'YOGEN-phase03-video-5MiB.mp4','mimeType':'video/mp4','fileData':base64.b64encode(padded).decode(),
       'requestId':'phase03-video5-20261009'})
    report['checks'].append({'name':'video_5MiB_real_upload','ok':value.get('success') is True,'bytes':target,
        'base64Bytes':len(base64.b64encode(padded)),'elapsedMs':duration,'response':value})
    if value.get('success'):
        config['publicTestVideoId'] = value['fileId']
        (ROOT / 'config/drive.phase03.json').write_text(json.dumps(config,indent=2))
        record_file(value,'phase03-video5-20261009')
    print(json.dumps(report['checks'][-1],ensure_ascii=True))
(ROOT / 'phases/results/03/checks/media-cloud.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
