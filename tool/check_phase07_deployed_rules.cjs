const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),base='C:/Users/Dell/AppData/Roaming/npm/node_modules/firebase-tools/lib';
const {Command}=require(path.join(base,'command.js')),{requireAuth}=require(path.join(base,'requireAuth.js')),rules=require(path.join(base,'gcp/rules.js'));
const hash=text=>crypto.createHash('sha256').update(text.replace(/\r\n/g,'\n').trim()).digest('hex');
const command=new Command('yogen:phase07-rules').before(requireAuth).action(async options=>{
 const releases=await rules.listAllReleases(options.project),name=await rules.getLatestRulesetName(options.project,'cloud.firestore',releases),files=await rules.getRulesetContent(name);
 const localHash=hash(fs.readFileSync(path.join(root,'firebase/firestore.phase07.rules'),'utf8'));
 const deployedHash=files.length===1?hash(files[0].content):null;
 const result={projectId:options.project,ruleset:name,localHash,deployedHash,matchesStrictPhase07:localHash===deployedHash};
 fs.writeFileSync(path.join(root,'phases/results/07/checks/deployed-rules.json'),JSON.stringify(result,null,2));console.log(JSON.stringify({matchesStrictPhase07:result.matchesStrictPhase07}));if(!result.matchesStrictPhase07)process.exitCode=1;
});
command.runner()({project:'portfolio-14d15',config:'firebase.phase07.json',nonInteractive:true}).catch(()=>{console.log('Rules readback failed');process.exitCode=1;});
