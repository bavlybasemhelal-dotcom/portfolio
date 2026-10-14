// Update the existing deployment in place, keeping its URL, scopes and config.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';
const root=path.resolve(import.meta.dirname,'..');
const deps=path.join(root,'.runtime/phase10/tooling/node_modules');
const directory=path.join(root,'.runtime/image-fix/script-backup');
const cfgPath=path.join(root,'config/drive.phase05.json');
const cfg=JSON.parse(fs.readFileSync(cfgPath,'utf8'));
const normalize=value=>value.replace(/\r\n/g,'\n').trim();
const local=fs.readFileSync(path.join(root,'google_drive_script/yogen_phase05.js'),'utf8');
try {
  const {initAuth}=await import(pathToFileURL(path.join(deps,'@google/clasp/build/src/auth/auth.js')));
  const {google}=await import(pathToFileURL(path.join(deps,'googleapis/build/src/index.js')));
  const session=await initAuth({});
  const api=google.script({version:'v1',auth:session.credentials});
  const previous=(await api.projects.deployments.get({scriptId:cfg.scriptId,deploymentId:cfg.deploymentId})).data;
  const active=(await api.projects.getContent({scriptId:cfg.scriptId,versionNumber:previous.deploymentConfig.versionNumber})).data;
  const head=(await api.projects.getContent({scriptId:cfg.scriptId})).data;
  fs.mkdirSync(directory,{recursive:true});
  if(!fs.existsSync(path.join(directory,'before.json'))) fs.writeFileSync(path.join(directory,'before.json'),JSON.stringify({previous,active,head},null,2));
  const old=active.files.find(f=>f.name==='yogen_phase05');
  if(!old) throw Error('Active media service file was not found.');
  if(normalize(old.source)===normalize(local)) {
    console.log(JSON.stringify({alreadyDeployed:true,versionNumber:previous.deploymentConfig.versionNumber,url:cfg.webAppUrl}));
    process.exit(0);
  }
  const insertion="  if (receipt.storage === 'hosting') return p5ReadHostedImage(receipt);\n";
  const start=local.indexOf('// Existing imported covers');
  const withoutFix=local.slice(0,start).replace(insertion,'');
  if(normalize(old.source)!==normalize(withoutFix)) throw Error('Active source changed outside this fix; no overwrite performed.');
  if(head.files.some(f=>!active.files.some(a=>a.name===f.name&&normalize(a.source)===normalize(f.source)))) {
    throw Error('Unpublished script edits exist; no overwrite performed.');
  }
  const files=active.files.map(f=>({name:f.name,type:f.type,source:f.name==='yogen_phase05'?local:f.source}));
  await api.projects.updateContent({scriptId:cfg.scriptId,requestBody:{files}});
  const version=(await api.projects.versions.create({scriptId:cfg.scriptId,requestBody:{description:'Read verified existing Hosting images alongside Drive media'}})).data;
  const observed=(await api.projects.getContent({scriptId:cfg.scriptId,versionNumber:version.versionNumber})).data;
  if(!files.every(f=>observed.files.some(v=>v.name===f.name&&normalize(v.source)===normalize(f.source)))) throw Error('Version source readback mismatch.');
  const deploymentConfig={...previous.deploymentConfig,versionNumber:version.versionNumber,description:'YOGEN media compatibility: hosted image receipts and Drive uploads'};
  const deployed=(await api.projects.deployments.update({scriptId:cfg.scriptId,deploymentId:cfg.deploymentId,requestBody:{deploymentConfig}})).data;
  const url=deployed.entryPoints?.find(p=>p.webApp)?.webApp?.url;
  if(url!==cfg.webAppUrl) throw Error('Deployment URL changed unexpectedly.');
  cfg.versionNumber=version.versionNumber;
  fs.writeFileSync(cfgPath,JSON.stringify(cfg,null,2)+'\n');
  const receipt={scriptId:cfg.scriptId,deploymentId:cfg.deploymentId,url,previousVersion:previous.deploymentConfig.versionNumber,
    versionNumber:version.versionNumber,sourceSha256:crypto.createHash('sha256').update(local).digest('hex'),
    sameDeploymentUrl:true,configurationPreserved:true,oauthScopesUnchanged:true,sourceReadbackVerified:true};
  fs.writeFileSync(path.join(root,'updates/1.0.2/records/media-service-deployment.json'),JSON.stringify(receipt,null,2));
  console.log(JSON.stringify(receipt));
} catch(e) {
  console.error(JSON.stringify({deployed:false,error:e.response?'Google API request failed':e.message,status:e.response?.status||null}));
  process.exitCode=1;
}
