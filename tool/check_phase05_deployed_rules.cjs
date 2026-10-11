const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),base='C:/Users/Dell/AppData/Roaming/npm/node_modules/firebase-tools/lib';
const {Command}=require(path.join(base,'command.js')),{requireAuth}=require(path.join(base,'requireAuth.js')),rules=require(path.join(base,'gcp/rules.js'));
const hash=text=>crypto.createHash('sha256').update(text.replace(/\r\n/g,'\n').trim()).digest('hex');
const command=new Command('yogen:phase05-rules').before(requireAuth).action(async options=>{
 const releases=await rules.listAllReleases(options.project),name=await rules.getLatestRulesetName(options.project,'cloud.firestore',releases),files=await rules.getRulesetContent(name);
 const localHash=hash(fs.readFileSync(path.join(root,'firebase/firestore.phase05.rules'),'utf8'));
 const deployedHash=files.length===1?hash(files[0].content):null;
 const result={projectId:options.project,ruleset:name,localHash,deployedHash,matchesStrictPhase05:localHash===deployedHash};
 fs.writeFileSync(path.join(root,'phases/results/05/checks/deployed-rules.json'),JSON.stringify(result,null,2));console.log(JSON.stringify({matchesStrictPhase05:result.matchesStrictPhase05}));if(!result.matchesStrictPhase05)process.exitCode=1;
});
command.runner()({project:'portfolio-14d15',config:'firebase.phase05.json',nonInteractive:true}).catch(()=>{console.log('Rules readback failed');process.exitCode=1;});
