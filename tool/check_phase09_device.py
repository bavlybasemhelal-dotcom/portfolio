"""Read-only device/cloud evidence; never exports authentication credentials."""
import argparse, json, pathlib, subprocess, urllib.request, urllib.error
root = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('stage', choices=['before', 'archived', 'restored', 'republished'])
args = parser.parse_args()
cfg = json.loads((root/'config/firebase.web.json').read_text(encoding='utf-8'))
owner = json.loads((root/'.runtime/yogen-owner.local.json').read_text(encoding='utf-8'))
def request(url, value=None, token=None):
    headers = {'Content-Type':'application/json'}
    if token: headers['Authorization']='Bearer '+token
    req = urllib.request.Request(url, data=json.dumps(value).encode() if value is not None else None, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as response: return json.load(response)
    except urllib.error.HTTPError as error:
        if error.code == 404: return None
        raise RuntimeError('HTTP '+str(error.code)) from None
auth = request('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key='+cfg['FIREBASE_API_KEY'],
    {'email':owner.get('email',owner['loginName']), 'password':owner['password'],'returnSecureToken':True})
def decode(value):
    if 'mapValue' in value: return {k:decode(v) for k,v in value['mapValue'].get('fields',{}).items()}
    if 'arrayValue' in value: return [decode(v) for v in value['arrayValue'].get('values',[])]
    if 'integerValue' in value: return int(value['integerValue'])
    return next(iter(value.values()))
def document(collection, id):
    raw=request('https://firestore.googleapis.com/v1/projects/portfolio-14d15/databases/(default)/documents/sites/phase04-test/'+collection+'/'+id, token=auth['idToken'])
    return None if raw is None else {k:decode(v) for k,v in raw['fields'].items()}
fixture=json.loads((root/'phases/results/05/checks/dart-rest-cloud.json').read_text(encoding='utf-8'))
project=fixture['projectId']
draft=document('projectDrafts',project)
published=document('projects',project)
references=[]
for id in draft['content']['mediaIds']:
    media=document('media',id)['public']
    references.append({k:media.get(k,'') for k in ['id','driveFileId','thumbnailDriveFileId']})
out=root/'phases/results/09/checks'
result={'stage':args.stage,'site':'phase04-test','projectId':project,'status':draft['status'],
    'revision':draft['revision'],'mediaIds':draft['content']['mediaIds'], 'references':references,
    'published':published is not None, 'readOnlyProbe':True}
if args.stage!='before':
    before=json.loads((out/'device-before.json').read_text(encoding='utf-8'))
    result['sameDriveReferences']=before['references']==references
    result['sameMediaOrder']=before['mediaIds']==result['mediaIds']
(out/('device-'+args.stage+'.json')).write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({k:result[k] for k in result if k not in ['references','mediaIds']}))
