"""Recover the exact Flutter NDK package from Google's verified repository archive."""
import hashlib,json,pathlib,time,urllib.request,zipfile,xml.etree.ElementTree as ET
workspace=pathlib.Path(__file__).resolve().parent.parent
runtime=workspace/'.runtime'
metadata=ET.fromstring(urllib.request.urlopen('https://dl.google.com/android/repository/repository2-3.xml',timeout=45).read())
archive=None
for package in metadata.iter():
    if package.tag.endswith('remotePackage') and package.get('path')=='ndk;28.2.13676358':
        for item in package.iter():
            if item.tag.endswith('archive'):
                values={v.tag.split('}')[-1]:v.text for v in item.iter() if len(v)==0}
                if values.get('host-os')=='windows': archive=values
if not archive or archive['url']!='android-ndk-r28c-windows.zip': raise RuntimeError('Unexpected repository archive')
destination=runtime/archive['url']
url='https://dl.google.com/android/repository/'+archive['url']
digest=hashlib.sha1()
with urllib.request.urlopen(url,timeout=60) as response,destination.open('wb') as output:
    total=0;last=time.monotonic()
    while data:=response.read(1024*1024):
        output.write(data);digest.update(data);total+=len(data)
        if time.monotonic()-last>5:
            print(json.dumps({'downloadedMiB':round(total/1024/1024),'totalMiB':round(int(archive['size'])/1024/1024)}),flush=True);last=time.monotonic()
if total!=int(archive['size']) or digest.hexdigest()!=archive['checksum']: raise RuntimeError('Archive verification failed')
target=runtime/'ndk28-repaired'
target.mkdir(exist_ok=True)
with zipfile.ZipFile(destination) as z:
    for item in z.infolist():
        resolved=(target/item.filename).resolve()
        if not resolved.is_relative_to(target.resolve()): raise RuntimeError('Unsafe archive path')
    z.extractall(target)
source=target/'android-ndk-r28c'
if not (source/'source.properties').is_file(): raise RuntimeError('Missing NDK metadata')
evidence={'url':url,'size':total,'sha1':digest.hexdigest(),'matchesOfficialChecksum':True,'sourceProperties':(source/'source.properties').read_text()}
(workspace/'phases/results/07/checks/ndk-archive.json').write_text(json.dumps(evidence,indent=2),encoding='utf-8')
print(json.dumps({'verifiedAndExtracted':True}),flush=True)
