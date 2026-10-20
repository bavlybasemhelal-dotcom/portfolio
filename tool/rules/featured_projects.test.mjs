import fs from 'node:fs';
import path from 'node:path';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, collection, getDocs, setDoc, deleteDoc, serverTimestamp, Timestamp, setLogLevel} from 'firebase/firestore';
setLogLevel('silent');
const root=path.resolve(import.meta.dirname,'../..'),base='sites/yogen';
const env=await initializeTestEnvironment({projectId:'demo-yogen-featured',firestore:{host:'127.0.0.1',port:8085,
 rules:fs.readFileSync(path.join(root,'firebase/firestore.company-media.rules'),'utf8')}});
const checks=[];
const value=(id,actor)=>({projectId:id,updatedAt:serverTimestamp(),updatedBy:actor});
async function check(name,body){await body();checks.push(name);}
try{
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async c=>{
  for(const [id,role,enabled] of [['manager','manager',true],['editor','editor',true],['disabled','editor',false]])
   await setDoc(doc(c.firestore(),base+'/adminUsers/'+id),{role,enabled});
  await setDoc(doc(c.firestore(),base+'/projects/published-a'),{projectId:'published-a'});
 });
 const visitor=env.unauthenticatedContext().firestore();
 const manager=env.authenticatedContext('manager').firestore(),editor=env.authenticatedContext('editor').firestore();
 const marker=db=>doc(db,base+'/featuredProjects/published-a');
 await check('Manager can feature a published project',()=>assertSucceeds(setDoc(marker(manager),value('published-a','manager'))));
 await check('Public can read the featured selection',()=>assertSucceeds(getDocs(collection(visitor,base+'/featuredProjects'))));
 await check('Editors can manage the selection',()=>assertSucceeds(setDoc(marker(editor),value('published-a','editor'))));
 await check('Anonymous, disabled and roleless writes are rejected',async()=>{
  for(const db of [visitor,env.authenticatedContext('disabled').firestore(),env.authenticatedContext('outsider').firestore()])
   await assertFails(setDoc(marker(db),value('published-a','editor')));
 });
 await check('Unpublished projects cannot be selected',()=>assertFails(setDoc(doc(editor,base+'/featuredProjects/private-a'),value('private-a','editor'))));
 await check('Mismatched project IDs are rejected',()=>assertFails(setDoc(marker(editor),value('different-id','editor'))));
 await check('Forged actor and timestamps are rejected',async()=>{
  await assertFails(setDoc(marker(editor),value('published-a','manager')));
  await assertFails(setDoc(marker(editor),{...value('published-a','editor'),updatedAt:Timestamp.fromMillis(0)}));
 });
 await check('Unexpected fields are rejected',()=>assertFails(setDoc(marker(editor),{...value('published-a','editor'),privateNote:'forged'})));
 await check('Anonymous cannot remove a featured project',()=>assertFails(deleteDoc(marker(visitor))));
 await check('Editor can remove featured status',()=>assertSucceeds(deleteDoc(marker(editor))));
 console.log(JSON.stringify({passed:checks.length,checks}));
}finally{await env.cleanup();}
