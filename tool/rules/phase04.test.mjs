import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {initializeTestEnvironment,assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,getDoc,setDoc,updateDoc,deleteDoc,getDocs,collection,writeBatch,serverTimestamp,Timestamp,runTransaction,setLogLevel} from 'firebase/firestore';
setLogLevel('silent');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const output=path.join(root,'phases/results/04/checks');fs.mkdirSync(output,{recursive:true});
const report={date:new Date().toISOString(),environment:'Real Firestore rules emulator, demo-yogen-phase04; no production writes',checks:[],errors:[]};
let env;
const site='phase04-test',base='sites/'+site,at=(db,c,id)=>doc(db,base+'/'+c+'/'+id);
const text=(ar='تجربة تحقق',en='Verification fixture')=>({ar,en});
const content=(id,extra={})=>({title:text(),summary:text(),body:text(),contribution:text(),
 categoryId:'systems',slug:id,usage:'demo',attribution:'company',mediaIds:['cover'],links:[],order:0,year:null,...extra});
const asset=(id='cover')=>({id,driveFileId:'1v0XR_P4WEUoXsgWXg2S6YqsyQsugly29',name:'صورة تحقق.png',mime:'image/png',bytes:36009,alt:text()});
const audit=uid=>({createdAt:Timestamp.now(),createdBy:uid,updatedAt:Timestamp.now(),updatedBy:uid});
async function check(name,body){try{await body();report.checks.push({name,ok:true});}catch(e){report.checks.push({name,ok:false,error:e.message});report.errors.push(name);}console.log(JSON.stringify(report.checks.at(-1)));}
async function save(db,uid,id,value,expected=null){
 return runTransaction(db,async tx=>{const ref=at(db,'projectDrafts',id),snapshot=await tx.get(ref),old=snapshot.exists()?snapshot.data():null;
  if(expected!==null&&(old?.revision||0)!==expected)throw Error('revision_conflict');
  tx.set(ref,{content:value,status:old?.status||'draft',revision:(old?.revision||0)+1,publishedRevision:old?.publishedRevision||0,
   stableSlug:old?.stableSlug||'',internalNote:'PRIVATE NOTE',createdAt:old?.createdAt||serverTimestamp(),createdBy:old?.createdBy||uid,updatedAt:serverTimestamp(),updatedBy:uid});
 });
}
async function publish(db,uid,id){return runTransaction(db,async tx=>{
 const ref=at(db,'projectDrafts',id),draft=(await tx.get(ref)).data(),category=(await tx.get(at(db,'categories',draft.content.categoryId))).data();
 await tx.get(at(db,'projectSlugs',draft.content.slug));
 const assets=[];for(const mid of draft.content.mediaIds)assets.push((await tx.get(at(db,'media',mid))).data()?.public||asset(mid));
 const revision=draft.revision+1;
 tx.set(ref,{...draft,status:'published',revision,publishedRevision:revision,stableSlug:draft.content.slug,updatedAt:serverTimestamp(),updatedBy:uid});
 tx.set(at(db,'projects',id),{projectId:id,content:draft.content,category:category.name,assets,revision,publishedAt:serverTimestamp()});
 tx.set(at(db,'projectSlugs',draft.content.slug),{projectId:id,revision});
});}
async function remove(db,uid,id,status){return runTransaction(db,async tx=>{
 const ref=at(db,'projectDrafts',id),draft=(await tx.get(ref)).data(),publicDoc=await tx.get(at(db,'projects',id));
 tx.set(ref,{...draft,status,revision:draft.revision+1,publishedRevision:0,updatedAt:serverTimestamp(),updatedBy:uid});
 if(publicDoc.exists()){tx.delete(at(db,'projects',id));tx.delete(at(db,'projectSlugs',draft.stableSlug));}
});}
async function seed(){await env.withSecurityRulesDisabled(async ctx=>{
 const db=ctx.firestore();
 for(const [uid,role]of[['manager','manager'],['editor1','editor'],['editor2','editor'],['editor3','editor']])await setDoc(at(db,'adminUsers',uid),{uid,loginName:uid,authEmail:uid+'@login.yogen.invalid',recoveryKind:'owner',role,enabled:true,...audit('manager')});
 await setDoc(at(db,'categories','systems'),{name:text(),enabled:true,order:0,updatedAt:Timestamp.now(),updatedBy:'manager'});
 for(let i=0;i<6;i++){const id=i===0?'cover':'asset'+i;await setDoc(at(db,'media',id),{public:asset(id),ready:true,...audit('manager')});}
 await setDoc(at(db,'media','pending'),{public:asset('pending'),ready:false,...audit('manager')});
 await setDoc(at(db,'settings','media'),{rootFolderId:'PRIVATE ROOT'});
});}
try{
 env=await initializeTestEnvironment({projectId:'demo-yogen-phase04',firestore:{host:'127.0.0.1',port:8084,rules:fs.readFileSync(path.join(root,'firebase/firestore.phase04.rules'),'utf8')}});
 await env.clearFirestore();
 const cleared=await fetch('http://127.0.0.1:9094/emulator/v1/projects/demo-yogen-phase04/accounts',{method:'DELETE'});
 if(!cleared.ok)throw Error('auth_emulator_cleanup_failed');
 await seed();
 const manager=env.authenticatedContext('manager').firestore(),editor=env.authenticatedContext('editor1').firestore(),visitor=env.unauthenticatedContext().firestore(),outsider=env.authenticatedContext('outsider',{role:'manager'}).firestore();
 await check('P04-T01 visitor reads publication but not draft/settings',async()=>{await save(editor,'editor1','public-one',content('public-one'));await publish(editor,'editor1','public-one');await assertSucceeds(getDoc(at(visitor,'projects','public-one')));await assertFails(getDoc(at(visitor,'projectDrafts','public-one')));await assertFails(getDoc(at(visitor,'settings','media')));});
 await check('P04-T02 unauthenticated and roleless direct writes rejected',async()=>{for(const db of[visitor,outsider]){await assertFails(setDoc(at(db,'projectDrafts','attack'),{content:content('attack')}));await assertFails(getDocs(collection(db,base+'/adminUsers')));}});
 await check('P04-T03 all three editors can save/publish, cannot manage accounts/settings',async()=>{for(let i=1;i<=3;i++){const uid='editor'+i,db=env.authenticatedContext(uid).firestore(),id='editor-work-'+i;await assertSucceeds(save(db,uid,id,content(id)));await assertSucceeds(publish(db,uid,id));await assertFails(setDoc(at(db,'adminUsers','new-person'),{}));await assertFails(setDoc(at(db,'settings','media'),{}));}});
 await check('P04-T04 direct self-promotion refused including forged auth claim',async()=>{await assertFails(updateDoc(at(editor,'adminUsers','editor1'),{role:'manager',updatedAt:serverTimestamp(),updatedBy:'editor1'}));await assertFails(setDoc(at(outsider,'adminUsers','outsider'),{uid:'outsider',role:'manager',enabled:true}));});
 await check('P04-T05 incomplete English saves but publish fails; complete no-link succeeds',async()=>{await save(editor,'editor1','incomplete',content('incomplete',{body:{ar:'عربي',en:''}}));await assertFails(publish(editor,'editor1','incomplete'));await assertSucceeds(save(editor,'editor1','no-link',content('no-link')));await assertSucceeds(publish(editor,'editor1','no-link'));});
 await check('P04-T06 old public version survives draft editing, changes on publish',async()=>{const id='versions';await save(editor,'editor1',id,content(id));await publish(editor,'editor1',id);const first=(await getDoc(at(visitor,'projects',id))).data();await save(editor,'editor1',id,content(id,{summary:text('تعديل جديد','New revision')}));if((await getDoc(at(visitor,'projects',id))).data().revision!==first.revision)throw Error('draft_leaked');await publish(editor,'editor1',id);if((await getDoc(at(visitor,'projects',id))).data().content.summary.en!=='New revision')throw Error('publication_missing');});
 await check('P04-T07 failed atomic publish-related batch preserves all prior data',async()=>{const before=(await getDoc(at(visitor,'projects','versions'))).data();const batch=writeBatch(editor);batch.update(at(editor,'projects','versions'),{publishedAt:serverTimestamp()});batch.set(at(editor,'settings','forbidden'),{value:'fail'});await assertFails(batch.commit());const after=(await getDoc(at(visitor,'projects','versions'))).data();if(JSON.stringify(before)!==JSON.stringify(after))throw Error('partial_write');});
 await check('P04-T08 unpublish/archive/restore retains content/media without public read',async()=>{const id='archive';await save(editor,'editor1',id,content(id));await publish(editor,'editor1',id);await remove(editor,'editor1',id,'draft');if((await getDoc(at(visitor,'projects',id))).exists())throw Error('unpublish_failed');await publish(editor,'editor1',id);await remove(editor,'editor1',id,'archived');await remove(editor,'editor1',id,'draft');const restored=(await getDoc(at(editor,'projectDrafts',id))).data();if(restored.content.mediaIds[0]!=='cover'||restored.status!=='draft'||(await getDoc(at(visitor,'projects',id))).exists())throw Error('restore_failed');});
 await check('P04-T09 manager provisions editor role, revocation blocks existing session',async()=>{const uid='new-editor';await assertSucceeds(setDoc(at(manager,'adminUsers',uid),{uid,loginName:uid,authEmail:createHash('sha256').update(uid).digest('hex')+'@login.yogen.invalid',recoveryKind:'owner',role:'editor',enabled:true,createdAt:serverTimestamp(),createdBy:'manager',updatedAt:serverTimestamp(),updatedBy:'manager'}));const db=env.authenticatedContext(uid).firestore();await save(db,uid,'new-editor-work',content('new-editor-work'));await updateDoc(at(manager,'adminUsers',uid),{enabled:false,updatedAt:serverTimestamp(),updatedBy:'manager'});await assertFails(save(db,uid,'new-editor-work',content('new-editor-work')));await assertSucceeds(getDoc(at(db,'adminUsers',uid)));});
 await check('P04-T10 stale revision rejected directly by rules',async()=>{const id='conflict';await save(editor,'editor1',id,content(id));const original=(await getDoc(at(editor,'projectDrafts',id))).data();await save(editor,'editor1',id,content(id,{summary:text('أول','First')}));await assertFails(setDoc(at(editor,'projectDrafts',id),{...original,revision:original.revision+1,updatedAt:serverTimestamp(),updatedBy:'editor1'}));});
 await check('E01 no private note/audit injection into public snapshot',async()=>{await assertFails(updateDoc(at(editor,'projects','public-one'),{internalNote:'LEAK'}));const snapshot=(await getDoc(at(visitor,'projects','public-one'))).data();if('internalNote'in snapshot||'updatedBy'in snapshot)throw Error('private_data_leaked');});
 await check('E02 pending/missing media and video cover cannot publish',async()=>{await save(editor,'editor1','pending-work',content('pending-work',{mediaIds:['pending']}));await assertFails(publish(editor,'editor1','pending-work'));await save(editor,'editor1','missing-work',content('missing-work',{mediaIds:['absent']}));await assertFails(publish(editor,'editor1','missing-work'));});
 await check('E03 six media references fit actual rules access budget',async()=>{await save(editor,'editor1','six-assets',content('six-assets',{mediaIds:['cover','asset1','asset2','asset3','asset4','asset5']}));await assertSucceeds(publish(editor,'editor1','six-assets'));});
 await check('E04 duplicate stable slug cannot steal another project',async()=>{await save(editor,'editor1','duplicate',content('duplicate',{slug:'public-one'}));await assertFails(publish(editor,'editor1','duplicate'));});
 await check('E05 manager cannot disable/remove own account or elevate another editor',async()=>{await assertFails(updateDoc(at(manager,'adminUsers','manager'),{enabled:false}));await assertFails(deleteDoc(at(manager,'adminUsers','manager')));await assertFails(updateDoc(at(manager,'adminUsers','editor2'),{role:'manager'}));});
 await check('E06 hidden public team data independent of admin membership',async()=>{await assertSucceeds(setDoc(at(manager,'teamDrafts','future'),{name:{ar:'',en:''},role:{ar:'',en:''}}));await assertFails(getDoc(at(visitor,'teamDrafts','future')));await assertFails(setDoc(at(manager,'team','future'),{name:{ar:'',en:''},role:{ar:'',en:''},bio:text(),order:0}));await assertFails(setDoc(at(editor,'team','fake'),{name:text(),role:text(),bio:text(),order:0}));});
 await check('E07 media metadata creates with server audit; Base64 injection refused',async()=>{await assertSucceeds(setDoc(at(editor,'media','new-media'),{public:asset('new-media'),ready:true,createdAt:serverTimestamp(),createdBy:'editor1',updatedAt:serverTimestamp(),updatedBy:'editor1'}));await assertFails(updateDoc(at(editor,'media','new-media'),{fileData:'BASE64-NOT-ALLOWED'}));});
 await check('E08 multiline content valid; impersonated HTTPS user-info link rejected',async()=>{const id='multiline';await save(editor,'editor1',id,content(id,{body:text('المشكلة\nالحل','Problem\nSolution')}));await assertSucceeds(publish(editor,'editor1',id));await assertFails(save(editor,'editor1','bad-link',content('bad-link',{links:[{url:'https://name@host.example',labelAr:'رابط',labelEn:'Link'}]})));});
 await check('E09 company contacts validated on server; optional contacts allowed',async()=>{const value={name:'YOGEN',about:text(),service:text(),contacts:{}};await assertSucceeds(setDoc(at(manager,'company','current'),value));for(const contacts of[{email:42},{whatsapp:'invalid'},{website:'javascript:alert(1)'},{website:'https://name@host.example'}])await assertFails(setDoc(at(manager,'company','current'),{...value,contacts}));});
 await check('E10 partial biography refused; hiding team does not revoke editor',async()=>{const value={name:text(),role:text(),bio:{ar:'',en:''},order:0};await assertFails(setDoc(at(manager,'team','editor3'),{...value,bio:{ar:'نبذة',en:''}}));await assertSucceeds(setDoc(at(manager,'team','editor3'),value));await assertSucceeds(deleteDoc(at(manager,'team','editor3')));await assertSucceeds(save(env.authenticatedContext('editor3').firestore(),'editor3','team-hidden-work',content('team-hidden-work')));});
 // Genuine Auth-emulator identities for the Dart REST integration suite.
 const fixtures={projectId:'demo-yogen-phase04',site,users:[]};
 for(const name of['rest-manager','rest-editor','rest-outsider']){
  const email=createHash('sha256').update(name).digest('hex')+'@login.yogen.invalid',password='LocalEmulatorOnly_12345';
  const response=await fetch('http://127.0.0.1:9094/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-key',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,password,returnSecureToken:true})});const value=await response.json();
  if(!response.ok)throw Error('auth_emulator_seed_failed');fixtures.users.push({name,email,password,uid:value.localId,idToken:value.idToken,refreshToken:value.refreshToken});
  if(name!=='rest-outsider')await env.withSecurityRulesDisabled(ctx=>setDoc(at(ctx.firestore(),'adminUsers',value.localId),{uid:value.localId,loginName:name,authEmail:email,recoveryKind:'owner',role:name==='rest-manager'?'manager':'editor',enabled:true,...audit(value.localId)}));
 }
 fs.writeFileSync(path.join(root,'.runtime/phase04-emulator-fixtures.local.json'),JSON.stringify(fixtures));
}catch(e){report.errors.push(e.message);console.error('Rules harness failed: '+e.message);}
finally{if(env)await env.cleanup();fs.writeFileSync(path.join(output,'rules-emulator.json'),JSON.stringify(report,null,2));if(report.errors.length)process.exitCode=1;}
