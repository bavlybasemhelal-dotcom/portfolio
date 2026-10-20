// Authorized owner import using the active Firebase CLI account. No tokens are
// read from files, printed, or persisted. Hosting must be deployed first.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const cli = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const { Command } = require(path.join(cli, 'command.js'));
const { requireAuth } = require(path.join(cli, 'requireAuth.js'));
const { Client } = require(path.join(cli, 'apiv2.js'));
const out = path.join(root, 'content/company-projects');
const database = 'projects/portfolio-14d15/databases/(default)';
const documents = database + '/documents';
const api = new Client({urlPrefix: 'https://firestore.googleapis.com', apiVersion: 'v1'});
const rules = new Client({urlPrefix: 'https://firebaserules.googleapis.com', apiVersion: 'v1'});
const docPath = (collection, id) => documents + '/sites/yogen/' + collection + '/' + id;
const encode = v => v === null ? {nullValue: null} : Array.isArray(v) ? {arrayValue:{values:v.map(encode)}} :
  typeof v === 'object' ? {mapValue:{fields:Object.fromEntries(Object.entries(v).map(([k,x])=>[k,encode(x)]))}} :
  typeof v === 'boolean' ? {booleanValue:v} : typeof v === 'number' ? {integerValue:String(v)} : {stringValue:v};
const decode = v => 'mapValue' in v ? Object.fromEntries(Object.entries(v.mapValue.fields||{}).map(([k,x])=>[k,decode(x)])) :
  'arrayValue' in v ? (v.arrayValue.values||[]).map(decode) : 'integerValue' in v ? Number(v.integerValue) : Object.values(v)[0];
const fields = v => Object.fromEntries(Object.entries(v).map(([k,x])=>[k,encode(x)]));
async function get(name) { try { return (await api.get(name)).body; } catch(e) { if(e.status===404 || e.context?.response?.statusCode===404) return null; throw e; } }
const command = new Command('yogen:company-import').before(requireAuth).action(async () => {
  fs.mkdirSync(path.join(root,'.runtime/company-import'),{recursive:true});
  if(process.argv.includes('--verify-release')) {
    const release=(await rules.get('projects/portfolio-14d15/releases/cloud.firestore')).body;
    const set=(await rules.get(release.rulesetName)).body;
    const source=set.source.files.find(f=>f.name.endsWith('.rules')) || set.source.files[0];
    const normalize=v=>v.replace(/\r\n/g,'\n').trim();
    const matches=normalize(source.content)===normalize(fs.readFileSync(path.join(root,'firebase/firestore.company-media.rules'),'utf8'));
    const hosting=require(path.join(cli,'hosting/api.js'));
    const channel=await hosting.getChannel('portfolio-14d15','portfolio-14d15','live');
    const receipt={rulesMatchLocal:matches,ruleset:release.rulesetName,hostingVersion:channel.release.version.name,
      hostingRelease:channel.release.name,deployedAt:channel.release.releaseTime};
    fs.writeFileSync(path.join(out,'publication/firebase-release.json'),JSON.stringify(receipt,null,2));
    if(!matches) throw Error('Deployed rules differ from tested rules');
    console.log(JSON.stringify(receipt));return;
  }
  if(process.argv.includes('--prepare')) {
    const release = (await rules.get('projects/portfolio-14d15/releases/cloud.firestore')).body;
    const set = (await rules.get(release.rulesetName)).body;
    const source = set.source.files.find(f=>f.name.endsWith('.rules')) || set.source.files[0];
    fs.writeFileSync(path.join(root,'.runtime/company-import/deployed.rules'), source.content);
    fs.writeFileSync(path.join(root,'.runtime/company-import/rules-before.json'), JSON.stringify(release,null,2));
    const backups = [];
    for(const p of JSON.parse(fs.readFileSync(path.join(out,'projects.json'),'utf8')).projects) {
      for(const [collection,id] of [['projectDrafts',p.projectId],['projects',p.projectId],['projectSlugs',p.content.slug]]) {
        backups.push({collection,id,document:await get(docPath(collection,id))});
      }
    }
    fs.writeFileSync(path.join(root,'.runtime/company-import/documents-before.json'),JSON.stringify(backups,null,2));
    console.log(JSON.stringify({prepared:true,backedUpProjects:backups.filter(b=>b.collection==='projects').length,ruleset:release.rulesetName}));
    return;
  }
  if(!process.argv.includes('--publish')) throw Error('Use --prepare or --publish');
  if(!fs.existsSync(path.join(root,'.runtime/company-import/documents-before.json'))) throw Error('Preflight backup required');
  const catalog=JSON.parse(fs.readFileSync(path.join(out,'projects.json'),'utf8'));
  const categoryMap=Object.fromEntries(catalog.categories.map(c=>[c.id,c.name]));
  // Verify every hosted byte before any publication write.
  for(const p of catalog.projects) for(const m of p.media) {
    const response=await fetch('https://portfolio-14d15.web.app/project-media/'+m.sha256+'.jpg');
    const bytes=Buffer.from(await response.arrayBuffer());
    if(!response.ok || !response.headers.get('content-type')?.startsWith('image/jpeg') ||
      bytes.length!==m.bytes || crypto.createHash('sha256').update(bytes).digest('hex')!==m.sha256) throw Error('Hosted file mismatch: '+m.file);
  }
  const status=JSON.parse(fs.readFileSync(path.join(out,'publish-status.json'),'utf8'));
  status.status='publishing'; status.publicationMethod='Firebase owner import with verified Hosting images';
  for(const p of catalog.projects) {
    const draftDoc=await get(docPath('projectDrafts',p.projectId));
    if(!draftDoc) throw Error('Missing existing draft '+p.projectId);
    const draft=Object.fromEntries(Object.entries(draftDoc.fields).map(([k,v])=>[k,decode(v)]));
    const category=await get(docPath('categories',p.content.categoryId));
    if(!category || decode(category.fields.enabled)!==true) throw Error('Category not enabled');
    const slugDoc=await get(docPath('projectSlugs',p.content.slug));
    if(slugDoc && decode(slugDoc.fields.projectId)!==p.projectId) throw Error('Slug conflict');
    const actor=draft.updatedBy || draft.createdBy;
    const assets=[], writes=[];
    const now={timestampValue:new Date().toISOString()};
    for(const m of p.media) {
      const id='m_'+crypto.createHash('sha256').update(p.projectId+'|'+m.file+'|'+m.sha256).digest('hex');
      const publicUrl='https://portfolio-14d15.web.app/project-media/'+m.sha256+'.jpg';
      const asset={id,driveFileId:'',thumbnailDriveFileId:'',name:path.basename(m.file),mime:'image/jpeg',bytes:m.bytes,alt:m.alt,publicUrl};
      const source={folderId:'',originProjectId:p.projectId,scope:'project',requestId:'hosting-'+m.sha256,
        sha256:m.sha256,uploadedBy:actor,viewUrl:publicUrl,downloadUrl:publicUrl};
      const receipt={assetId:id,site:'yogen',public:true,storage:'hosting',publicUrl,fileId:'',thumbnailFileId:'',
        folderId:'',projectId:p.projectId,scope:'project',kind:'Images',requestId:source.requestId,
        sha256:m.sha256,uploadedBy:actor,viewUrl:publicUrl,downloadUrl:publicUrl,fileName:asset.name,mimeType:asset.mime,fileSize:m.bytes};
      const oldMedia=await get(docPath('media',id));
      const mediaFields=fields({public:asset,source,ready:true,verified:true,createdBy:actor,updatedBy:actor});
      mediaFields.createdAt=oldMedia?.fields.createdAt || now; mediaFields.updatedAt=now;
      writes.push({update:{name:docPath('mediaReceipts',id),fields:fields(receipt)}});
      writes.push({update:{name:docPath('media',id),fields:mediaFields}});
      assets.push(asset); m.publishedAssetId=id; m.publicUrl=publicUrl;
    }
    p.content.mediaIds=assets.map(a=>a.id);
    const revision=draft.revision+1;
    const draftFields={...draftDoc.fields,content:encode(p.content),status:encode('published'),revision:encode(revision),
      publishedRevision:encode(revision),stableSlug:encode(p.content.slug),updatedBy:encode(actor),updatedAt:now};
    writes.push({update:{name:docPath('projectDrafts',p.projectId),fields:draftFields},currentDocument:{updateTime:draftDoc.updateTime}});
    writes.push({update:{name:docPath('projects',p.projectId),fields:{...fields({projectId:p.projectId,content:p.content,
      category:categoryMap[p.content.categoryId],assets,revision}),publishedAt:now}}});
    writes.push({update:{name:docPath('projectSlugs',p.content.slug),fields:fields({projectId:p.projectId,revision})},
      currentDocument:slugDoc?{updateTime:slugDoc.updateTime}:{exists:false}});
    await api.post(documents+':commit',{writes});
    if(!status.publishedProjectIds.includes(p.projectId)) status.publishedProjectIds.push(p.projectId);
    status.hostedImagesPublished=(status.hostedImagesPublished||[]).filter(v=>v.projectId!==p.projectId)
      .concat(p.media.map(m=>({projectId:p.projectId,file:m.file,sha256:m.sha256,id:m.publishedAssetId,url:m.publicUrl})));
    fs.writeFileSync(path.join(out,'projects.json'),JSON.stringify(catalog,null,2));
    fs.writeFileSync(path.join(out,'publish-status.json'),JSON.stringify(status,null,2));
    console.log(JSON.stringify({published:p.projectId,images:assets.length,revision}));
  }
});
command.runner()({project:'portfolio-14d15',config:path.join(root,'firebase.json'),nonInteractive:true})
 .catch(e=>{console.error('Company import failed:',e.message);process.exitCode=1;});
