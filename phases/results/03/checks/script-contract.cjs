// Apps Script contract tests with mocks; real cloud evidence is separate.
const vm=require('node:vm'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../../..'), files=[], report={mocked:true,checks:[]};
const iter=values=>{let n=0;return{hasNext:()=>n<values.length,next:()=>values[n++]};};
const folder={getId:()=> 'test-folder-123',getParents:()=>iter([{getId:()=> 'root-folder-123'}]),getFiles:()=>iter(files),createFile:blob=>{
 const file={id:'test-file-'+String(files.length).padStart(10,'0'),description:'',access:'PRIVATE',getId(){return this.id},getName:()=>blob.name,getSize:()=>blob.bytes.length,getMimeType:()=>blob.mime,
 getDescription(){return this.description},setDescription(value){this.description=value},setSharing(access){this.access=access},getSharingAccess(){return this.access},getParents:()=>iter([folder]),getBlob:()=>({getBytes:()=>blob.bytes})};files.push(file);return file;
}};
const decode=x=>[...Buffer.from(x,'base64')],encode=x=>Buffer.from(x).toString('base64');
const context=vm.createContext({PropertiesService:{getScriptProperties:()=>({getProperties:()=>({FIREBASE_API_KEY:'test-public-key',ROOT_FOLDER_ID:'root-folder-123',TEST_FOLDER_ID:'test-folder-123',ALLOWED_UIDS:'allowed-test-uid'})})},
 ContentService:{MimeType:{JSON:'json'},createTextOutput:value=>({value,setMimeType(){return this}})},
 Utilities:{base64Decode:decode,base64DecodeWebSafe:decode,base64Encode:encode,DigestAlgorithm:{SHA_256:'sha256'},computeDigest:(_,bytes)=>[...crypto.createHash('sha256').update(Buffer.from(bytes)).digest()],newBlob:(bytes,mime,name)=>({bytes,mime,name,getDataAsString:()=>Buffer.from(bytes).toString()})},
 UrlFetchApp:{fetch:(_,options)=>{const token=JSON.parse(options.payload).idToken;const valid=token.startsWith('unit.');return{getResponseCode:()=>valid?200:400,getContentText:()=>JSON.stringify({users:[{localId:'allowed-test-uid'}]})}}},
 DriveApp:{Access:{ANYONE_WITH_LINK:'ANYONE_WITH_LINK'},Permission:{VIEW:'VIEW'},getFolderById:()=>folder,getFileById:id=>{const file=files.find(f=>f.id===id);if(!file)throw Error('missing');return file;}},
 LockService:{getScriptLock:()=>({tryLock:()=>true,releaseLock:()=>{}})},Date,JSON});
vm.runInContext(fs.readFileSync(path.join(root,'google_drive_script/yogen_phase03.js'),'utf8'),context);
const token='unit.'+Buffer.from(JSON.stringify({sub:'allowed-test-uid',aud:'portfolio-14d15',iss:'https://securetoken.google.com/portfolio-14d15',exp:Math.floor(Date.now()/1000)+3600,padding:'x'.repeat(100)})).toString('base64url')+'.signature';
const send=body=>JSON.parse(context.doPost({postData:{contents:JSON.stringify(body)}}).value);
const check=(name,fn)=>{try{fn();report.checks.push({name,ok:true})}catch(e){report.checks.push({name,ok:false,error:e.message});process.exitCode=1;}};
const png=fs.readFileSync(path.join(root,'assets/fixtures/phase03-test.png'));
const body={action:'upload',idToken:token,category:'phase03',requestId:'contract-test-01',fileName:'اختبار.png',mimeType:'image/png',fileData:png.toString('base64')};
check('Unauthenticated request creates no files',()=>{assert.equal(send({action:'upload'}).error,'authentication_required');assert.equal(files.length,0)});
check('Forged token rejected by Auth lookup',()=>{assert.equal(send({...body,idToken:'forged'.repeat(30)}).error,'invalid_identity');assert.equal(files.length,0)});
check('MIME and signature mismatch rejected',()=>{assert.equal(send({...body,mimeType:'video/mp4'}).error,'signature_mismatch');assert.equal(files.length,0)});
check('Malformed Base64 rejected',()=>assert.equal(send({...body,fileData:'A=AA'}).error,'invalid_base64'));
check('Arabic upload and idempotent retry',()=>{const a=send(body),b=send(body);assert.equal(a.success,true);assert.equal(a.fileId,b.fileId);assert.equal(files.length,1)});
check('Conflicting retry rejected',()=>assert.equal(send({...body,fileName:'another.png'}).error,'request_conflict'));
check('Public image and private read guard',()=>{assert.equal(send({action:'image',fileId:files[0].id}).fileData,body.fileData);files[0].access='PRIVATE';assert.equal(send({action:'image',fileId:files[0].id}).error,'not_public_test_image');files[0].access='ANYONE_WITH_LINK'});
check('5 MiB linear Base64 validation avoids stack overflow',()=>{const bytes=fs.readFileSync(path.join(root,'.runtime/video-5MiB.mp4'));const result=send({...body,requestId:'contract-video-01',fileName:'video.mp4',mimeType:'video/mp4',fileData:bytes.toString('base64')});assert.equal(result.success,true);assert.equal(result.fileSize,5*1024*1024)});
check('Oversized body refused before decode or Drive write',()=>{const count=files.length;assert.equal(send({...body,fileData:'A'.repeat(8*1024*1024)}).error,'request_too_large');assert.equal(files.length,count)});
fs.writeFileSync(path.join(__dirname,'script-contract.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
