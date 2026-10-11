// Use clasp's credential manager as intended; never inspect or print tokens.
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const base = 'C:/Users/Dell/AppData/Local/npm-cache/_npx/27bda8ea3e8461f3/node_modules';
const {initAuth} = await import(pathToFileURL(path.join(base,'@google/clasp/build/src/auth/auth.js')));
const {google} = await import(pathToFileURL(path.join(base,'googleapis/build/src/index.js')));
const root = path.resolve(import.meta.dirname,'..');
const config = JSON.parse(fs.readFileSync(path.join(root,'config/drive.phase03.json'),'utf8'));
try {
  const auth = await initAuth({});
  const api = google.script({version:'v1',auth:auth.credentials});
  const deployment = (await api.projects.deployments.get({scriptId:config.scriptId,deploymentId:config.deploymentId})).data;
  const content = (await api.projects.getContent({scriptId:config.scriptId,versionNumber:deployment.deploymentConfig.versionNumber})).data;
  const manifest = content.files.find(f=>f.name==='appsscript');
  const report = {deploymentId:deployment.deploymentId, config:deployment.deploymentConfig,
    entryPoints:deployment.entryPoints, manifest:JSON.parse(manifest.source)};
  fs.writeFileSync(path.join(root,'phases/results/03/checks/script-metadata.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report));
} catch(e) { console.log(JSON.stringify({error:'script_metadata_failed',httpStatus:e.response?.status,code:e.code})); process.exitCode=1; }
