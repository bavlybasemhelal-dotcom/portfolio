// Use the CLI's own authentication hooks and Rules API. Never inspect credentials.
const fs=require('node:fs'),path=require('node:path');
const base='C:/Users/Dell/AppData/Roaming/npm/node_modules/firebase-tools/lib';
const {Command}=require(path.join(base,'command.js'));
const {requireAuth}=require(path.join(base,'requireAuth.js'));
const rules=require(path.join(base,'gcp/rules.js'));
const root=path.resolve(__dirname,'..');
const command=new Command('yogen:rules-snapshot').before(requireAuth).action(async options=>{
 const releases=await rules.listAllReleases(options.project);
 const name=await rules.getLatestRulesetName(options.project,'cloud.firestore',releases);
 if(!name)throw Error('No deployed Firestore rules');
 const files=await rules.getRulesetContent(name);
 fs.writeFileSync(path.join(root,'firebase/firestore.before-phase04.rules'),files[0].content);
 fs.mkdirSync(path.join(root,'phases/results/04/checks'),{recursive:true});
 fs.writeFileSync(path.join(root,'phases/results/04/checks/rules-before.json'),JSON.stringify({projectId:options.project,ruleset:name,fileCount:files.length},null,2));
 console.log(JSON.stringify({projectId:options.project,rulesSnapshotSaved:true,fileCount:files.length}));
});
command.runner()({project:'portfolio-14d15',config:'firebase.phase04.json',nonInteractive:true}).catch(()=>{console.error('Rules snapshot failed; no deployment performed');process.exitCode=1;});
