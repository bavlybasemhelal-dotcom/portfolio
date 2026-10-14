"""Validate the portable company content package without changing cloud data."""
import hashlib, json, re, zipfile
from pathlib import Path
from urllib.parse import urlparse
from PIL import Image

ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'content/company-projects'
catalog=json.loads((OUT/'projects.json').read_text(encoding='utf-8'))
assert catalog['site']=='yogen' and len(catalog['projects'])>=15
assert len({p['projectId'] for p in catalog['projects']})==len(catalog['projects'])
assert len({p['content']['slug'] for p in catalog['projects']})==len(catalog['projects'])
categories={c['id'] for c in catalog['categories']}
files=[]
for p in catalog['projects']:
    c=p['content']
    assert c['categoryId'] in categories
    assert re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*',c['slug']) and len(c['slug'])<=80
    assert c['usage'] in ['real','demo','personal'] and c['attribution']=='company'
    for key in ['title','summary','body','contribution']:
        assert set(c[key])=={'ar','en'}
        assert all(isinstance(v,str) and v.strip() and len(v)<=30000 for v in c[key].values())
    assert 0<=c['order']<=1000000 and len(p['media'])<=6
    assert p['media']
    external=p['editorial']['externalUrl']
    if external:
        url=urlparse(external)
        assert url.scheme=='https' and url.hostname and not url.username
    for m in p['media']:
        file=(OUT/m['file']).resolve()
        assert file.is_relative_to(OUT.resolve()) and file.is_file()
        data=file.read_bytes()
        assert len(data)==m['bytes'] and 0<len(data)<=5*1024*1024
        assert hashlib.sha256(data).hexdigest()==m['sha256']
        assert all(s.strip() for s in m['alt'].values())
        with Image.open(file) as img:
            assert img.format=='JPEG' and max(img.size)<=1600
            img.verify()
        files.append(file)
summary={'projects':len(catalog['projects']),'categories':len(categories),'images':len(files),'totalImageBytes':sum(f.stat().st_size for f in files),'bilingualContentValid':True,'mediaHashesValid':True,'credentialsIncluded':False}
(OUT/'validation.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
with zipfile.ZipFile(OUT/'yogen-company-projects.zip','w',compression=zipfile.ZIP_DEFLATED) as archive:
    extra=[OUT/'publication-verification.json'] if (OUT/'publication-verification.json').exists() else []
    for file in [OUT/'projects.json',OUT/'review.html',OUT/'README.md',OUT/'validation.json',OUT/'publish-status.json',*extra,*files]:
        archive.write(file,file.relative_to(OUT).as_posix())
print(json.dumps(summary))
