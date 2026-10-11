// Read-only copy of the active Apps Script version using the existing clasp session.
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const root = path.resolve(import.meta.dirname,'..');
const base = path.join(root,'.runtime/phase10/tooling/node_modules');
try {
  const {initAuth} = await import(pathToFileURL(path.join(base,'@google/clasp/build/src/auth/auth.js')));
  const {google} = await import(pathToFileURL(path.join(base,'googleapis/build/src/index.js')));
  const config = JSON.parse(fs.readFileSync(path.join(root,'config/drive.phase05.json'),'utf8'));
  const session = await initAuth({});
  const api = google.script({version:'v1',auth:session.credentials});
  const source = (await api.projects.getContent({scriptId:config.scriptId,versionNumber:config.versionNumber})).data;
  const backup = path.join(root,'.runtime/phase10/private/backup');
  fs.mkdirSync(backup,{recursive:true});
  fs.writeFileSync(path.join(backup,'apps-script-active.json'),JSON.stringify({scriptId:config.scriptId,versionNumber:config.versionNumber,source},null,2));
  fs.writeFileSync(path.join(root,'phases/results/10/records/script-backup.json'),JSON.stringify({scriptId:config.scriptId,versionNumber:config.versionNumber,fileCount:source.files?.length||0,readOnly:true,restorationTestExecuted:false},null,2));
  console.log(JSON.stringify({activeScriptBackupSaved:true,versionNumber:config.versionNumber}));
} catch(error) {
  console.error(JSON.stringify({scriptBackupSaved:false,httpStatus:error.response?.status||null}));
  process.exitCode=1;
}
