"""Narrow first-role bootstrap, then always replace it with tested strict rules."""
import json
import pathlib
import shutil
import subprocess
import urllib.request

root=pathlib.Path(__file__).resolve().parent.parent
owner=json.loads((root/'.runtime/yogen-owner.local.json').read_text())
test_user=json.loads((root/'.runtime/firebase-test-user.local.json').read_text())
key=json.loads((root/'config/firebase.web.json').read_text())['FIREBASE_API_KEY']
checks=root/'phases/results/04/checks'
source=(root/'firebase/firestore.phase04.rules').read_text()
bootstrap=root/'.runtime/firestore.phase04.bootstrap.rules'
temporary_config=root/'firebase.phase04.bootstrap.json'
uid=owner['uid'];actor=test_user['uid']
assert actor=='QUUM6tS8dGbRd9rpwxOdEw5oLPS2' and owner['loginName']=='admin@gmail.com'
assert owner['projectId']=='portfolio-14d15' and uid.isalnum()
rule='''match /sites/{bootstrapSite}/adminUsers/{bootstrapUid} {
  allow create: if request.auth != null && request.auth.uid == ACTOR
    && bootstrapUid == OWNER && bootstrapSite in ['yogen','phase04-test']
    && request.resource.data.keys().hasAll(['uid','loginName','authEmail','recoveryKind','role','enabled','createdAt','createdBy','updatedAt','updatedBy'])
    && request.resource.data.keys().hasOnly(['uid','loginName','authEmail','recoveryKind','role','enabled','createdAt','createdBy','updatedAt','updatedBy'])
    && request.resource.data.uid == OWNER && request.resource.data.loginName == 'admin@gmail.com'
    && request.resource.data.authEmail == EMAIL && request.resource.data.role == 'manager'
    && request.resource.data.enabled == true && request.resource.data.recoveryKind == 'owner'
    && request.resource.data.createdAt == request.time && request.resource.data.updatedAt == request.time
    && request.resource.data.createdBy == ACTOR && request.resource.data.updatedBy == ACTOR;
}
'''.replace('ACTOR',json.dumps(actor)).replace('OWNER',json.dumps(uid)).replace('EMAIL',json.dumps(owner['email']))
bootstrap.write_text(source.replace('    match /sites/{site} {',rule+'    match /sites/{site} {'))
temporary_config.write_text(json.dumps({'firestore':{'database':'(default)','rules':'.runtime/firestore.phase04.bootstrap.rules'}}))
node=shutil.which('node');cli=pathlib.Path.home()/'AppData/Roaming/npm/node_modules/firebase-tools/lib/bin/firebase.js'
def deploy(config,log):
    with (checks/log).open('w',encoding='utf-8') as stream:
        result=subprocess.run([node,str(cli),'deploy','--only','firestore:rules','--project','portfolio-14d15','--config',config,'--non-interactive'],cwd=root,stdout=stream,stderr=subprocess.STDOUT)
    if result.returncode:raise RuntimeError('Rules deployment failed: '+log)
def call(url,body,token=None):
    request=urllib.request.Request(url,data=json.dumps(body).encode() if body is not None else None,
        headers={'Content-Type':'application/json',**({'Authorization':'Bearer '+token} if token else {})})
    with urllib.request.urlopen(request,timeout=30) as response:return json.load(response)
def login(user):return call('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key='+key,
    {'email':user['email'],'password':user['password'],'returnSecureToken':True})['idToken']
report={'projectId':'portfolio-14d15','managerUid':uid,'bootstrapSites':[],'strictRulesRestored':False}
try:
    deploy('firebase.phase04.bootstrap.json','deploy-bootstrap.txt')
    token=login(test_user)
    writes=[]
    for site in ['yogen','phase04-test']:
        values={'uid':uid,'loginName':owner['loginName'],'authEmail':owner['email'],'recoveryKind':'owner','role':'manager','enabled':True,'createdBy':actor,'updatedBy':actor}
        fields={k:{'booleanValue':v} if isinstance(v,bool) else {'stringValue':v} for k,v in values.items()}
        writes.append({'update':{'name':'projects/portfolio-14d15/databases/(default)/documents/sites/'+site+'/adminUsers/'+uid,'fields':fields},
            'updateTransforms':[{'fieldPath':f,'setToServerValue':'REQUEST_TIME'} for f in ['createdAt','updatedAt']]})
    call('https://firestore.googleapis.com/v1/projects/portfolio-14d15/databases/(default)/documents:commit',{'writes':writes},token)
    report['bootstrapSites']=['yogen','phase04-test']
finally:
    deploy('firebase.phase04.json','deploy-strict.txt')
    report['strictRulesRestored']=True
    temporary_config.unlink(missing_ok=True)
    (checks/'owner-bootstrap.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
