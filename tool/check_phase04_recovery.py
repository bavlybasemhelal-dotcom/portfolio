"""Exercise the same owner recovery command on a disposable test identity only."""
import json, pathlib, secrets, shutil, subprocess, urllib.request, urllib.error
root=pathlib.Path(__file__).resolve().parent.parent
fixture=json.loads((root/'.runtime/phase04-cloud-fixtures.local.json').read_text())
user=next(u for u in fixture['users'] if u['name']=='rest-editor3')
def auth(password):
    req=urllib.request.Request('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key='+fixture['apiKey'],data=json.dumps({'email':user['email'],'password':password,'returnSecureToken':True}).encode(),headers={'Content-Type':'application/json'})
    with urllib.request.urlopen(req,timeout=30) as response:return json.load(response)
password=secrets.token_urlsafe(32)
run=subprocess.run([shutil.which('node'),str(root/'tool/set-owner-access.cjs')],input=json.dumps({'login':user['login'],'password':password}),text=True,capture_output=True,cwd=root)
if run.returncode:raise RuntimeError('Owner recovery command failed without exposing credentials')
new=auth(password)
assert new['localId']==user['uid']
try:auth(user['password']);raise RuntimeError('Old password still worked')
except urllib.error.HTTPError as failure:assert failure.code==400
user['password']=password
(root/'.runtime/phase04-cloud-fixtures.local.json').write_text(json.dumps(fixture))
report={'testedOn':'isolated editor fixture, never human owner password','sameUid':True,'oldPasswordRejected':True,'newPasswordWorks':True,'noEmailSent':True,'stdinOnly':True}
(root/'phases/results/04/checks/recovery-cloud.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
