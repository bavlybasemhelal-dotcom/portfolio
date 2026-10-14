// Publish public profiles with the authorized, active Firebase CLI account.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),out=path.join(root,'content/company-team');
const cli=path.join(process.env.APPDATA,'npm/node_modules/firebase-tools/lib');
const {Command}=require(path.join(cli,'command.js')),{requireAuth}=require(path.join(cli,'requireAuth.js'));
const {Client}=require(path.join(cli,'apiv2.js'));
const api=new Client({urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1'});
const documents='projects/portfolio-14d15/databases/(default)/documents';
const doc=(collection,id)=>documents+'/sites/yogen/'+collection+'/'+id;
const encode=v=>v===null?{nullValue:null}:Array.isArray(v)?{arrayValue:{values:v.map(encode)}}:typeof v==='object'?{mapValue:{fields:fields(v)}}:typeof v==='boolean'?{booleanValue:v}:typeof v==='number'?{integerValue:String(v)}:{stringValue:v};
const fields=v=>Object.fromEntries(Object.entries(v).map(([k,x])=>[k,encode(x)]));
async function get(name){try{return(await api.get(name)).body;}catch(e){if(e.status===404||e.context?.response?.statusCode===404)return null;throw e;}}
const hash=v=>crypto.createHash('sha256').update(v).digest('hex');
async function readPhoto(url){
 for(let attempt=0;attempt<3;attempt++){
  try{const response=await fetch(url,{signal:AbortSignal.timeout(20000)});return{response,bytes:Buffer.from(await response.arrayBuffer())};}
  catch(e){if(attempt===2)throw e;await new Promise(resolve=>setTimeout(resolve,1000*(attempt+1)));}
 }
}
const command=new Command('yogen:team-import').before(requireAuth).action(async()=>{
 const catalog=JSON.parse(fs.readFileSync(path.join(out,'profiles.json'),'utf8'));
 const privateDir=path.join(root,'.runtime/company-team');fs.mkdirSync(privateDir,{recursive:true});
 if(process.argv.includes('--prepare')){
  const backup=[];
  for(const m of catalog.members){
   for(const collection of ['teamDrafts','team'])backup.push({collection,id:m.id,document:await get(doc(collection,m.id))});
   const bytes=fs.readFileSync(path.join(out,m.media.file));
   if(hash(bytes)!==m.media.sha256)throw Error('Local photo hash mismatch');
   const dir=path.join(root,'releases/company-projects/web/project-media');fs.mkdirSync(dir,{recursive:true});
   fs.writeFileSync(path.join(dir,m.media.sha256+'.jpg'),bytes);
  }
  const file=path.join(privateDir,'profiles-before.json');if(!fs.existsSync(file))fs.writeFileSync(file,JSON.stringify(backup,null,2));
  console.log(JSON.stringify({prepared:true,members:catalog.members.length}));return;
 }
 if(!process.argv.includes('--publish')||!fs.existsSync(path.join(privateDir,'profiles-before.json')))throw Error('Prepare and deploy photos first');
 for(const m of catalog.members){
  const publicUrl='https://portfolio-14d15.web.app/project-media/'+m.media.sha256+'.jpg';
  const {response,bytes}=await readPhoto(publicUrl);
  if(!response.ok||!response.headers.get('content-type')?.startsWith('image/jpeg')||bytes.length!==m.media.bytes||hash(bytes)!==m.media.sha256)throw Error('Hosted photo mismatch: '+m.id);
 }
 const status={site:'yogen',publishedMembers:[],verifiedHostedPhotos:3};
 for(const m of catalog.members){
  const mediaId='m_'+hash('team|'+m.id+'|'+m.media.sha256),actor='firebase-owner-import';
  const publicUrl='https://portfolio-14d15.web.app/project-media/'+m.media.sha256+'.jpg';
  const photo={id:mediaId,driveFileId:'',thumbnailDriveFileId:'',name:m.id+'.jpg',mime:'image/jpeg',bytes:m.media.bytes,alt:m.media.alt,publicUrl};
  const source={folderId:'',originProjectId:m.id,scope:'team',requestId:'hosting-'+m.media.sha256,
   sha256:m.media.sha256,uploadedBy:actor,viewUrl:publicUrl,downloadUrl:publicUrl};
  const receipt={assetId:mediaId,site:'yogen',public:true,storage:'hosting',publicUrl,fileId:'',thumbnailFileId:'',folderId:'',
   projectId:m.id,scope:'team',kind:'Images',requestId:source.requestId,sha256:m.media.sha256,uploadedBy:actor,
   viewUrl:publicUrl,downloadUrl:publicUrl,fileName:photo.name,mimeType:photo.mime,fileSize:photo.bytes};
  const [oldMedia,oldDraft,oldPublic]=await Promise.all([get(doc('media',mediaId)),get(doc('teamDrafts',m.id)),get(doc('team',m.id))]);
  const stamp={timestampValue:new Date().toISOString()};
  const mediaFields={...fields({public:photo,source,ready:true,verified:true,createdBy:actor,updatedBy:actor}),
   createdAt:oldMedia?.fields.createdAt||stamp,updatedAt:stamp};
  const profile={name:m.name,role:m.role,bio:m.bio,order:m.order,photo,links:m.links};
  const draft={name:m.name,role:m.role,bio:m.bio,order:m.order,photoId:mediaId,links:m.links,updatedBy:actor};
  await api.post(documents+':commit',{writes:[
   {update:{name:doc('mediaReceipts',mediaId),fields:fields(receipt)}},
   {update:{name:doc('media',mediaId),fields:mediaFields}},
   {update:{name:doc('teamDrafts',m.id),fields:{...(oldDraft?.fields||{}),...fields(draft),updatedAt:stamp}},currentDocument:oldDraft?{updateTime:oldDraft.updateTime}:{exists:false}},
   {update:{name:doc('team',m.id),fields:fields(profile)},currentDocument:oldPublic?{updateTime:oldPublic.updateTime}:{exists:false}}
  ]});
  m.media.publishedAssetId=mediaId;m.media.publicUrl=publicUrl;
  fs.writeFileSync(path.join(out,'profiles.json'),JSON.stringify(catalog,null,2));
  status.publishedMembers.push(m.id);fs.writeFileSync(path.join(out,'publish-status.json'),JSON.stringify(status,null,2));
  console.log(JSON.stringify({published:m.id}));
 }
});
command.runner()({project:'portfolio-14d15',config:path.join(root,'firebase.json'),nonInteractive:true})
 .catch(e=>{console.error('Team import failed:',e.message);process.exitCode=1;});
