// Read-only production backup via the Firebase CLI authentication hooks.
const fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '..');
const base = 'C:/Users/Dell/AppData/Roaming/npm/node_modules/firebase-tools/lib';
const {Command} = require(path.join(base, 'command.js'));
const {requireAuth} = require(path.join(base, 'requireAuth.js'));
const {Client} = require(path.join(base, 'apiv2.js'));
const rules = require(path.join(base, 'gcp/rules.js'));
const hosting = require(path.join(base, 'hosting/api.js'));
const directory = path.join(root, '.runtime/phase10/private/backup');
const project = 'portfolio-14d15', site = 'yogen';
const prefix = `projects/${project}/databases/(default)/documents`;
const client = new Client({urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1',auth:true});
const command = new Command('yogen:release-backup').before(requireAuth).action(async () => {
  fs.mkdirSync(directory, {recursive:true});
  const startedAt = new Date().toISOString(), documents = [];
  async function children(parent) {
    let pageToken;
    do {
      const response = await client.post(`${parent}:listCollectionIds`, {pageSize:100, ...(pageToken ? {pageToken}: {})});
      for (const collection of response.body.collectionIds || []) {
        let nextPage;
        do {
          const result = await client.get(`${parent}/${encodeURIComponent(collection)}`, {queryParams:{pageSize:100,showMissing:true,...(nextPage ? {pageToken:nextPage}: {})}});
          for (const document of result.body.documents || []) {
            if (document.fields) documents.push(document);
            await children(document.name);
          }
          nextPage = result.body.nextPageToken;
        } while (nextPage);
      }
      pageToken = response.body.nextPageToken;
    } while (pageToken);
  }
  await children(`${prefix}/sites/${site}`);
  const snapshot = {projectId:project,site,startedAt,finishedAt:new Date().toISOString(),transactional:false,documents};
  fs.writeFileSync(path.join(directory,'firestore-yogen.json'),JSON.stringify(snapshot,null,2));
  const ruleReleases = await rules.listAllReleases(project);
  const ruleName = await rules.getLatestRulesetName(project,'cloud.firestore',ruleReleases);
  const ruleFiles = ruleName ? await rules.getRulesetContent(ruleName) : [];
  fs.writeFileSync(path.join(directory,'firestore-rules.json'),JSON.stringify({ruleset:ruleName,files:ruleFiles},null,2));
  const channel = await hosting.getChannel(project,project,'live');
  fs.writeFileSync(path.join(directory,'hosting-before.json'),JSON.stringify({projectId:project,channel},null,2));
  const statuses = {};
  for (const doc of documents.filter(d=>d.name.startsWith(`${prefix}/sites/yogen/projectDrafts/`))) {
    const state=doc.fields.status?.stringValue || 'unknown'; statuses[state]=(statuses[state]||0)+1;
  }
  const summary = {projectId:project,site,documentCount:documents.length,
    publishedProjects:documents.filter(d=>d.name.startsWith(`${prefix}/sites/yogen/projects/`)).length,
    draftStatuses:statuses,mediaRecords:documents.filter(d=>d.name.startsWith(`${prefix}/sites/yogen/media/`)).length,
    rulesSnapshotSaved:!!ruleName,previousHostingVersion:channel?.release?.version?.name || null,
    authenticationPasswordsIncluded:false,transactional:false,restoreExecuted:false};
  fs.mkdirSync(path.join(root,'phases/results/10/records'),{recursive:true});
  fs.writeFileSync(path.join(root,'phases/results/10/records/backup-summary.json'),JSON.stringify(summary,null,2));
  console.log(JSON.stringify(summary));
});
command.runner()({project,config:'firebase.json',nonInteractive:true}).catch(error=>{
  console.error(JSON.stringify({backupFailed:true,status:error.status||null,reason:'Read-only backup did not finish; no production documents changed.'}));
  process.exitCode=1;
});
