// Only the two known temporary identities from this phase; retain labelled media for review.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),base='C:/Users/Dell/AppData/Roaming/npm/node_modules/firebase-tools/lib';
const {Command}=require(path.join(base,'command.js')),{requireAuth}=require(path.join(base,'requireAuth.js')),{Client}=require(path.join(base,'apiv2.js'));
const command=new Command('yogen:cleanup-phase05-tests').before(requireAuth).action(async()=>{
 const fixture=JSON.parse(fs.readFileSync(path.join(root,'.runtime/phase05-browser.local.json'),'utf8'));
 const identity=JSON.parse(fs.readFileSync(path.join(root,'config/identity.phase04.json'),'utf8'));
 if(fixture.site!=='phase04-test'||!/^phase05-editor-[0-9]+$/.test(fixture.editorLogin)||!/^phase05-outsider-[0-9]+$/.test(fixture.outsiderLogin)||[fixture.editorUid,fixture.outsiderUid].includes(identity.managerUid))throw Error('Fixture guard');
 const firestore=new Client({urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1'}),auth=new Client({urlPrefix:'https://identitytoolkit.googleapis.com',apiVersion:'v1'}),safe={skipLog:{body:true,resBody:true}};
 const prefix='/projects/portfolio-14d15/databases/(default)/documents';
 const name=prefix+'/sites/phase04-test/adminUsers/'+fixture.editorUid;
 const doc=(await firestore.get(name,safe)).body;
 if(doc.fields.loginName.stringValue!==fixture.editorLogin||doc.fields.createdBy.stringValue!==identity.managerUid)throw Error('Unexpected role record');
 await firestore.post(prefix+':commit',{writes:[{update:{name:doc.name,fields:{...doc.fields,enabled:{booleanValue:false},updatedBy:{stringValue:identity.managerUid}}},updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]}]},safe);
 let deleted=0;
 for(const uid of[fixture.editorUid,fixture.outsiderUid]){await auth.post('/projects/portfolio-14d15/accounts:delete',{localId:uid},safe);deleted++;}
 const report={site:'phase04-test',disabledTestRoles:1,deletedTemporaryAuth:deleted,ownerPreserved:true,realTeamAccountsCreated:0,labelledMediaAndTestProjectRetained:true};
 fs.writeFileSync(path.join(root,'phases/results/05/checks/fixtures-cleanup.json'),JSON.stringify(report,null,2));
 console.log(JSON.stringify(report));
});
command.runner()({project:'portfolio-14d15',config:'firebase.phase05.json',nonInteractive:true}).catch(()=>{console.log('Phase05 fixture cleanup failed; owner was not targeted');process.exitCode=1;});
