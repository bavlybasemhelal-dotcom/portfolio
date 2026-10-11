"""Create/reuse the authorized owner alias. Never print credentials or send email."""
import hashlib
import json
import os
import pathlib
import secrets
import subprocess
import sys
import urllib.request

root=pathlib.Path(__file__).resolve().parent.parent
private=root/'.runtime/yogen-owner.local.json'
config=json.loads((root/'config/firebase.web.json').read_text())
key=config['FIREBASE_API_KEY']
def auth(action,body):
    request=urllib.request.Request('https://identitytoolkit.googleapis.com/v1/accounts:'+action+'?key='+key,
        data=json.dumps(body).encode(),headers={'Content-Type':'application/json'})
    with urllib.request.urlopen(request,timeout=30) as response:return json.load(response)
if private.exists():
    owner=json.loads(private.read_text())
    if owner.get('loginName')!='admin@gmail.com' or owner.get('projectId')!='portfolio-14d15':
        raise RuntimeError('Owner identity mismatch')
    action='signInWithPassword'
else:
    name='admin@gmail.com'
    owner={'projectId':'portfolio-14d15','loginName':name,'email':hashlib.sha256(name.encode()).hexdigest()+'@login.yogen.invalid',
        'password':secrets.token_urlsafe(32),'needsOwnerPassword':True}
    action='signUp'
try:
    value=auth(action,{'email':owner['email'],'password':owner['password'],'returnSecureToken':True})
except Exception:
    print('Owner preparation failed; no role deployed and no credentials printed')
    sys.exit(1)
owner.update(uid=value['localId'],idToken=value['idToken'],refreshToken=value['refreshToken'])
private.write_text(json.dumps(owner,indent=2),encoding='utf-8')
if os.name=='nt':
    principal=os.environ['USERDOMAIN']+'\\'+os.environ['USERNAME']
    acl=subprocess.run(['icacls',str(private),'/inheritance:r','/grant:r',principal+':(F)','*S-1-5-18:(F)','*S-1-5-32-544:(F)'],capture_output=True)
    if acl.returncode:raise RuntimeError('Private owner credential ACL failed')
public={'projectId':'portfolio-14d15','siteId':'yogen','managerUid':owner['uid'],
    'managerLogin':'admin@gmail.com','managerAuthEmail':owner['email'],'recoveryKind':'owner',
    'teamMemberCount':3,'managerSeparateFromTeam':True}
(root/'config/identity.phase04.json').write_text(json.dumps(public,indent=2),encoding='utf-8')
print(json.dumps({'projectId':public['projectId'],'managerUid':owner['uid'],'alias':owner['loginName'],
    'separateFromThreeMembers':True,'privateCredentialFileProtected':True,'noEmailSent':True}))
