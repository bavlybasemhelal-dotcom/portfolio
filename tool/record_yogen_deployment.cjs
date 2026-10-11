// Store a release receipt only. Does not open the site or run acceptance tests.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),base='C:/Users/Dell/AppData/Roaming/npm/node_modules/firebase-tools/lib';
const {Command}=require(path.join(base,'command.js')),{requireAuth}=require(path.join(base,'requireAuth.js'));
const hosting=require(path.join(base,'hosting/api.js'));
const command=new Command('yogen:release-receipt').before(requireAuth).action(async()=>{
 const [_,version,build]=fs.readFileSync(path.join(root,'pubspec.yaml'),'utf8').match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$/m);
 const before=process.argv.includes('--before');
 const site=await hosting.getSite('portfolio-14d15','portfolio-14d15');
 const channel=await hosting.getChannel('portfolio-14d15','portfolio-14d15','live');
 const record={projectId:'portfolio-14d15',site:'portfolio-14d15',url:site.defaultUrl,
   releaseId:before?null:`yogen-${version}+${build}`,candidateReleaseId:before?`yogen-${version}+${build}`:null,hostingVersion:channel?.release?.version?.name||null,
   hostingRelease:channel?.release?.name||null,deployedAt:channel?.release?.releaseTime||null,
   scope:'public-live',runtimeTestsExecuted:false,apiReceiptOnly:true};
 fs.writeFileSync(path.join(root,before?`updates/${version}/records/hosting-before.json`:`releases/${version}/deployment.json`),JSON.stringify(record,null,2));
 console.log(JSON.stringify(record));
});
command.runner()({project:'portfolio-14d15',config:path.join(root,'firebase.json'),nonInteractive:true}).catch(()=>{console.error('Could not record Hosting release metadata. No application test performed.');process.exitCode=1;});
