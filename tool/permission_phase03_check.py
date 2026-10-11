"""Temporary non-allowlisted Auth account; verify denial, then delete it."""
import json,pathlib,secrets,urllib.request,urllib.error
ROOT=pathlib.Path(__file__).resolve().parents[1]
config=json.loads((ROOT/'config/firebase.web.json').read_text())
drive=json.loads((ROOT/'config/drive.phase03.json').read_text())
def auth(action,data):
    request=urllib.request.Request('https://identitytoolkit.googleapis.com/v1/accounts:'+action+'?key='+config['FIREBASE_API_KEY'],
        data=json.dumps(data).encode(),headers={'Content-Type':'application/json'})
    with urllib.request.urlopen(request,timeout=25) as r:return json.load(r)
user=auth('signUp',{'email':'phase03-denial-'+secrets.token_hex(6)+'@example.invalid',
    'password':secrets.token_urlsafe(28),'returnSecureToken':True})
report={'projectId':'portfolio-14d15','checks':[]}
try:
    request=urllib.request.Request(drive['webAppUrl'],data=json.dumps({'action':'ping','idToken':user['idToken'],'role':'admin'}).encode(),
        headers={'Content-Type':'text/plain;charset=utf-8'})
    with urllib.request.urlopen(request,timeout=60) as r:result=json.load(r)
    report['checks'].append({'name':'Valid Firebase account outside server allowlist rejected despite client admin role',
        'ok':result.get('error')=='upload_not_allowed','response':result})
    url='https://firestore.googleapis.com/v1/projects/portfolio-14d15/databases/(default)/documents/phase03_checks/'+user['localId']+'/runs/denial-test'
    request=urllib.request.Request(url,data=json.dumps({'fields':{'testOnly':{'booleanValue':True}}}).encode(),method='PATCH',
        headers={'Content-Type':'application/json','Authorization':'Bearer '+user['idToken']})
    try:
        urllib.request.urlopen(request,timeout=20)
        report['checks'].append({'name':'Non-allowlisted Firestore account rejected','ok':False})
    except urllib.error.HTTPError as e:
        report['checks'].append({'name':'Non-allowlisted Firestore account rejected','ok':e.code==403,'httpStatus':e.code})
finally:
    auth('delete',{'idToken':user['idToken']})
    report['temporaryAccountDeleted']=True
    (ROOT/'phases/results/03/checks/permissions-cloud.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
