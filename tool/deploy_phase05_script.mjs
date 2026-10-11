// Official clasp authentication and Google API clients; no credential extraction.
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
const base = 'C:/Users/Dell/AppData/Local/npm-cache/_npx/27bda8ea3e8461f3/node_modules';
const { initAuth } = await import(pathToFileURL(path.join(base, '@google/clasp/build/src/auth/auth.js')));
const { google } = await import(pathToFileURL(path.join(base, 'googleapis/build/src/index.js')));
const root = path.resolve(import.meta.dirname, '..');
const config = JSON.parse(fs.readFileSync(path.join(root, 'config/drive.phase03.json'), 'utf8'));
const firebase = JSON.parse(fs.readFileSync(path.join(root, 'config/firebase.web.json'), 'utf8'));
const owner = JSON.parse(fs.readFileSync(path.join(root, 'config/identity.phase04.json'), 'utf8'));
const output = path.join(root, 'phases/results/05/checks'); fs.mkdirSync(output, { recursive: true });
try {
  const auth = await initAuth({});
  const api = google.script({ version: 'v1', auth: auth.credentials });
  const old = (await api.projects.getContent({ scriptId: config.scriptId })).data;
  const backup = path.join(root, '.runtime/script-before-phase05.local.json');
  if (!fs.existsSync(backup)) fs.writeFileSync(backup, JSON.stringify(old));
  const publicConfig = { FIREBASE_API_KEY: firebase.FIREBASE_API_KEY, OWNER_UID: owner.managerUid,
    ROOT_FOLDER_ID: config.rootFolderId, PROJECTS_FOLDER_ID: config.projectsFolderId,
    BRAND_FOLDER_ID: config.brandFolderId, TEAM_FOLDER_ID: config.teamFolderId, TESTS_FOLDER_ID: config.testFolderId };
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'google_drive_script/appsscript.json'), 'utf8'));
  if (!manifest.oauthScopes.includes('https://www.googleapis.com/auth/datastore')) manifest.oauthScopes.push('https://www.googleapis.com/auth/datastore');
  fs.writeFileSync(path.join(root, 'google_drive_script/appsscript.json'), JSON.stringify(manifest, null, 2));
  fs.writeFileSync(path.join(root, 'google_drive_script/phase05_config.js'), '// Public configuration only. No credentials.\nconst YOGEN_PHASE05_CONFIG = ' + JSON.stringify(publicConfig, null, 2) + ';\n');
  const files = [{ name: 'appsscript', type: 'JSON', source: JSON.stringify(manifest) },
    { name: 'phase05_config', type: 'SERVER_JS', source: fs.readFileSync(path.join(root, 'google_drive_script/phase05_config.js'), 'utf8') },
    { name: 'yogen_phase05', type: 'SERVER_JS', source: fs.readFileSync(path.join(root, 'google_drive_script/yogen_phase05.js'), 'utf8') }];
  await api.projects.updateContent({ scriptId: config.scriptId, requestBody: { files } });
  const version = (await api.projects.versions.create({ scriptId: config.scriptId, requestBody: { description: 'YOGEN media service with roles and server receipts' } })).data;
  const observedFiles = (await api.projects.getContent({ scriptId: config.scriptId, versionNumber: version.versionNumber })).data.files;
  const observedManifest = JSON.parse(observedFiles.find(f => f.name === 'appsscript').source);
  if (!manifest.oauthScopes.every(scope => observedManifest.oauthScopes.includes(scope)) ||
      !files.every(file => observedFiles.some(f => f.name === file.name && f.source === file.source))) {
    throw Error('Published version does not match requested sources and scopes');
  }
  // Separate deployment preserves the verified phase 3 endpoint and its version.
  const phase05Path = path.join(root, 'config/drive.phase05.json');
  const deploymentConfig = { versionNumber: version.versionNumber, manifestFileName: 'appsscript', description: 'YOGEN Phase 05 media' };
  const deployed = fs.existsSync(phase05Path)
    ? (await api.projects.deployments.update({ scriptId: config.scriptId,
        deploymentId: JSON.parse(fs.readFileSync(phase05Path, 'utf8')).deploymentId, requestBody: { deploymentConfig } })).data
    : (await api.projects.deployments.create({ scriptId: config.scriptId, requestBody: deploymentConfig })).data;
  const entry = deployed.entryPoints.find(p => p.webApp);
  if (!entry?.webApp?.url) throw Error('No observed Web App URL');
  const next = { ...config, webAppUrl: entry.webApp.url, DRIVE_WEB_APP_URL: entry.webApp.url,
    deploymentId: deployed.deploymentId, versionNumber: version.versionNumber, status: 'phase05_pending_verification' };
  fs.writeFileSync(path.join(root, 'config/drive.phase05.json'), JSON.stringify(next, null, 2));
  fs.writeFileSync(path.join(output, 'script-deployment.json'), JSON.stringify({ scriptId: config.scriptId,
    deploymentId: deployed.deploymentId, versionNumber: version.versionNumber, entryPoints: deployed.entryPoints,
    previousDeploymentPreserved: config.deploymentId, scopes: observedManifest.oauthScopes,
    versionSourceReadbackVerified: true }, null, 2));
  console.log(JSON.stringify({ deploymentId: deployed.deploymentId, versionNumber: version.versionNumber, url: entry.webApp.url }));
} catch (e) { console.error(JSON.stringify({ error: 'phase05_script_deploy_failed', httpStatus: e.response?.status, code: e.code })); process.exitCode = 1; }
