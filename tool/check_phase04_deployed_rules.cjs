// Read deployed rules through official CLI authentication; never inspect credentials.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const base = 'C:/Users/Dell/AppData/Roaming/npm/node_modules/firebase-tools/lib';
const { Command } = require(path.join(base, 'command.js'));
const { requireAuth } = require(path.join(base, 'requireAuth.js'));
const rules = require(path.join(base, 'gcp/rules.js'));
const root = path.resolve(__dirname, '..');
const normalize = text => text.replace(/\r\n/g, '\n').trim();
const digest = text => crypto.createHash('sha256').update(normalize(text)).digest('hex');
const command = new Command('yogen:verify-rules').before(requireAuth).action(async options => {
  const releases = await rules.listAllReleases(options.project);
  const name = await rules.getLatestRulesetName(options.project, 'cloud.firestore', releases);
  if (!name) throw Error('No deployed Firestore rules');
  const files = await rules.getRulesetContent(name);
  const localHash = digest(fs.readFileSync(path.join(root, 'firebase/firestore.phase04.rules'), 'utf8'));
  const deployedHash = files.length === 1 ? digest(files[0].content) : null;
  const result = { projectId: options.project, ruleset: name, matchesStrictPhase04: deployedHash === localHash, localHash, deployedHash };
  fs.writeFileSync(path.join(root, 'phases/results/04/checks/deployed-rules.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify({ projectId: options.project, matchesStrictPhase04: result.matchesStrictPhase04 }));
  if (!result.matchesStrictPhase04) process.exitCode = 1;
});
command.runner()({ project: 'portfolio-14d15', config: 'firebase.phase04.json', nonInteractive: true })
  .catch(() => { console.error('Deployed rules verification failed; no mutation performed'); process.exitCode = 1; });
