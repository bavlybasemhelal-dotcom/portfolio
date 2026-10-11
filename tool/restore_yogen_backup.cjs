// Manual recovery utility. Not executed as part of phase 10 delivery.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const base='C:/Users/Dell/AppData/Roaming/npm/node_modules/firebase-tools/lib';
const {Command}=require(path.join(base,'command.js')),{requireAuth}=require(path.join(base,'requireAuth.js'));
const {Client}=require(path.join(base,'apiv2.js'));
const args=process.argv.slice(2),arg=name=>args.includes(name)?args[args.indexOf(name)+1]:null;
const backupPath=arg('--backup')||path.join(root,'.runtime/phase10/private/backup/firestore-yogen.json');
const backup=JSON.parse(fs.readFileSync(backupPath,'utf8'));
const prefix='projects/portfolio-14d15/databases/(default)/documents/sites/yogen/';
if(backup.projectId!=='portfolio-14d15'||backup.site!=='yogen'||!Array.isArray(backup.documents))throw Error('Wrong project or backup site.');
const collections=arg('--collections')?.split(','),ids=arg('--ids')?.split(',');
const documents=backup.documents.filter(d=>d.name.startsWith(prefix)&&
  (!collections||collections.includes(d.name.slice(prefix.length).split('/')[0]))&&
  (!ids||ids.includes(d.name.split('/').at(-1))));
if(!documents.length||documents.length>400)throw Error('Select between 1 and 400 documents per atomic recovery.');
if(!args.includes('--apply')){
  console.log(JSON.stringify({mode:'plan-only',selectedDocuments:documents.length,networkRequests:0,writes:0}));
  process.exit(0);
}
if(arg('--confirm')!=='yogen')throw Error('Manual recovery requires --confirm yogen.');
const overwrite=args.includes('--overwrite');
const client=new Client({urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1',auth:true});
const command=new Command('yogen:manual-recovery').before(requireAuth).action(async()=>{
  const writes=[];
  for(const document of documents){
    let currentDocument={exists:false};
    if(overwrite){
      try {
        const current=await client.get(document.name);
        currentDocument={updateTime:current.body.updateTime};
      } catch(error){if(error.status!==404)throw error;}
    }
    writes.push({update:{name:document.name,fields:document.fields},currentDocument});
  }
  const result=await client.post('projects/portfolio-14d15/databases/(default)/documents:commit',{writes});
  console.log(JSON.stringify({restoredDocuments:writes.length,commitTime:result.body.commitTime,filesReuploaded:false}));
});
command.runner()({project:'portfolio-14d15',config:path.join(root,'firebase.json'),nonInteractive:true}).catch(()=>{
  console.error('Recovery did not complete. Existing-document conflicts and concurrent changes reject the atomic commit.');process.exitCode=1;
});
