// Remove only accounts created by phase 04 checks; preserve the real owner.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),base=path.join(os.homedir(),'AppData/Roaming/npm/node_modules/firebase-tools/lib');
const {Command}=require(path.join(base,'command.js')),{requireAuth}=require(path.join(base,'requireAuth.js')),{Client}=require(path.join(base,'apiv2.js'));
const identity=JSON.parse(fs.readFileSync(path.join(root,'config/identity.phase04.json'),'utf8'));
const command=new Command('yogen:cleanup-test-identities').before(requireAuth).action(async()=>{
 const firestore=new Client({urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1'}),auth=new Client({urlPrefix:'https://identitytoolkit.googleapis.com',apiVersion:'v1'}),safe={skipLog:{body:true,resBody:true}};
 const database='/projects/portfolio-14d15/databases/(default)/documents';
 const rows=await firestore.post(database+'/sites/phase04-test:runQuery',{structuredQuery:{from:[{collectionId:'adminUsers'}],limit:100}},safe);
 const runs=new Set(),report={site:'phase04-test',disabledTestRoles:0,deletedTestAuth:0,ownerPreserved:true,publicTestProjectsRemaining:null};
 for(const row of rows.body){const doc=row.document;if(!doc)continue;const fields=doc.fields,login=fields.loginName?.stringValue,uid=fields.uid?.stringValue;
  if(uid===identity.managerUid)continue;
  if(fields.role?.stringValue!=='editor'||fields.createdBy?.stringValue!==identity.managerUid||!/^(rest-editor[23]?|created-by-dart|browser-fixture)-[0-9]+$/.test(login||''))continue;
  if(/^rest-editor/.test(login))runs.add(login.split('-').at(-1));
  await firestore.post(database+':commit',{writes:[{update:{name:doc.name,fields:{...fields,enabled:{booleanValue:false},updatedBy:{stringValue:identity.managerUid}}},updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]}]},safe);report.disabledTestRoles++;
  try{await auth.post('/projects/portfolio-14d15/accounts:delete',{localId:uid},safe);report.deletedTestAuth++;}catch(e){if(!String(e.message).includes('USER_NOT_FOUND'))throw Error('Test identity cleanup failed');}
 }
 for(const run of runs){const email=crypto.createHash('sha256').update('rest-outsider-'+run).digest('hex')+'@login.yogen.invalid';const found=await auth.post('/projects/portfolio-14d15/accounts:lookup',{email:[email]},safe);for(const user of found.body.users||[]){if(user.localId===identity.managerUid)throw Error('Owner guard');await auth.post('/projects/portfolio-14d15/accounts:delete',{localId:user.localId},safe);report.deletedTestAuth++;}}
 const publicRows=await firestore.post(database+'/sites/phase04-test:runQuery',{structuredQuery:{from:[{collectionId:'projects'}],limit:100}},safe);report.publicTestProjectsRemaining=publicRows.body.filter(v=>v.document).length;
 if(report.publicTestProjectsRemaining!==0)throw Error('A public test project remains; inspect isolated data');
 fs.writeFileSync(path.join(root,'phases/results/04/checks/fixtures-cleanup.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
});
command.runner()({project:'portfolio-14d15',config:'firebase.phase04.json',nonInteractive:true}).catch(()=>{console.error('Test fixture cleanup failed; owner account was not targeted');process.exitCode=1;});
