import fs from 'node:fs';
import path from 'node:path';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,setDoc,updateDoc,serverTimestamp,setLogLevel} from 'firebase/firestore';
setLogLevel('silent');
const root=path.resolve(import.meta.dirname,'../..'), base='sites/yogen';
const hash='a'.repeat(64), id='m_'+hash, driveId='m_'+'b'.repeat(64);
const url='https://portfolio-14d15.web.app/project-media/'+hash+'.jpg';
const receipt={assetId:id,site:'yogen',public:true,storage:'hosting',publicUrl:url,fileId:'',thumbnailFileId:'',
 folderId:'',projectId:'project-a',scope:'project',kind:'Images',requestId:'hosting-'+hash,
 sha256:hash,uploadedBy:'manager',viewUrl:url,downloadUrl:url,fileName:'cover.jpg',mimeType:'image/jpeg',fileSize:100};
const media=(r,actor='manager')=>({public:{id:r.assetId,driveFileId:r.fileId,thumbnailDriveFileId:r.thumbnailFileId,
 name:r.fileName,mime:r.mimeType,bytes:r.fileSize,alt:{ar:'صورة المشروع',en:'Project image'},...(r.publicUrl?{publicUrl:r.publicUrl}:{})},
 source:{folderId:r.folderId,originProjectId:r.projectId,scope:r.scope,requestId:r.requestId,sha256:r.sha256,
 uploadedBy:r.uploadedBy,viewUrl:r.viewUrl,downloadUrl:r.downloadUrl},ready:true,verified:true,
 createdAt:serverTimestamp(),updatedAt:serverTimestamp(),createdBy:actor,updatedBy:actor});
const env=await initializeTestEnvironment({projectId:'demo-yogen-company',firestore:{host:'127.0.0.1',port:8085,
 rules:fs.readFileSync(path.join(root,'firebase/firestore.company-media.rules'),'utf8')}});
const checks=[];
async function check(name, fn){await fn();checks.push(name);}
try {
 await env.clearFirestore();
 const drive={...receipt,assetId:driveId,fileId:'public-drive-123456',thumbnailFileId:'thumbnail-drive-123456',folderId:'drive-folder-123456'};
 delete drive.storage;delete drive.publicUrl;
 await env.withSecurityRulesDisabled(async context=>{const db=context.firestore();
  await setDoc(doc(db,base+'/adminUsers/manager'),{role:'manager',enabled:true});
  await setDoc(doc(db,base+'/mediaReceipts/'+id),receipt);
  await setDoc(doc(db,base+'/mediaReceipts/'+driveId),drive);
 });
 const manager=env.authenticatedContext('manager').firestore(),visitor=env.unauthenticatedContext().firestore();
 await check('Existing Drive receipts remain valid',()=>assertSucceeds(setDoc(doc(manager,base+'/media/'+driveId),media(drive))));
 await check('Verified hosted image is accepted',()=>assertSucceeds(setDoc(doc(manager,base+'/media/'+id),media(receipt))));
 await check('Bilingual alt remains editable',()=>assertSucceeds(updateDoc(doc(manager,base+'/media/'+id),{
  'public.alt':{ar:'وصف الصورة',en:'Updated image description'},updatedAt:serverTimestamp(),updatedBy:'manager'})));
 await check('Clients cannot create trusted receipts',()=>assertFails(setDoc(doc(manager,base+'/mediaReceipts/m_'+'c'.repeat(64)),receipt)));
 await check('Anonymous media writes rejected',()=>assertFails(setDoc(doc(visitor,base+'/media/'+id),media(receipt))));
 for(const [label,bad] of [['External host',url.replace('portfolio-14d15.web.app','example.com')],
 ['Wrong byte hash',url.replace(hash,'c'.repeat(64))],['Unexpected path',url.replace('project-media','other')]]) {
  await check(label+' rejected',()=>assertFails(updateDoc(doc(manager,base+'/media/'+id),{
   'public.publicUrl':bad,updatedAt:serverTimestamp(),updatedBy:'manager'})));
 }
 await check('Drive receipt cannot authorize a hosted URL',()=>assertFails(updateDoc(doc(manager,base+'/media/'+driveId),{
  'public.publicUrl':url,updatedAt:serverTimestamp(),updatedBy:'manager'})));
 fs.writeFileSync(path.join(root,'content/company-projects/publication/rules-tests.json'),JSON.stringify({passed:checks.length,checks},null,2));
 console.log(JSON.stringify({passed:checks.length}));
} finally {await env.cleanup();}
