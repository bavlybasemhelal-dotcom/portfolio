const h=require('./phase07_browser_helpers.cjs');const {chromium,fs,path,root,out,login,open,text,token,doc,seek}=h;
const report={environment:'Actual manager controls and independent editor session, isolated test site',checks:[],errors:[]};let b;
const write=()=>fs.writeFileSync(path.join(out,'checks/browser-access-changes.json'),JSON.stringify(report,null,2));
(async()=>{try{
 const accounts=JSON.parse(fs.readFileSync(path.join(root,'.runtime/phase07-accounts.local.json'),'utf8')).accounts,account=accounts.filter(v=>v.login.startsWith('phase07-ui-member')).at(-1);if(!account)throw Error('UI test editor unavailable');
 b=await chromium.launch({channel:'chrome',headless:true});const managerCtx=await b.newContext({viewport:{width:1440,height:950}}),editorCtx=await b.newContext({viewport:{width:1440,height:950}});
 for(const c of [managerCtx,editorCtx])await c.addInitScript(()=>{localStorage.setItem('flutter.language','"en"');localStorage.setItem('flutter.motionPaused','true');});
 const p=await managerCtx.newPage(),member=await editorCtx.newPage();await login(p);await login(member,account);await open(p,'/admin/accounts');const tk=await token();
 const user=p.getByText(account.login,{exact:false}).or(p.getByLabel(account.login,{exact:false})).last();
 async function rowAction(label){await seek(p,user);const u=await user.boundingBox(),buttons=p.getByRole('button',{name:label,exact:true});let target=null,delta=Infinity;for(let i=0;i<await buttons.count();i++){const v=buttons.nth(i),box=await v.boundingBox();if(box){const d=Math.abs(box.y+box.height/2-u.y-u.height/2);if(d<delta){delta=d;target=v;}}}if(!target||delta>24)throw Error('Exact account row action unavailable');await target.click();}
 await rowAction('Disable access');
 await member.waitForURL(u=>u.hash.startsWith('#/admin/login'),{timeout:45000});report.checks.push({name:'P07-T11 disabling through UI revokes independent editor session',ok:(await doc(account.uid,tk,'adminUsers')).enabled===false});write();
 await rowAction('Enable access');await p.waitForTimeout(1500);report.checks.push({name:'P07-T11 UI enables editor while manager remains signed in',ok:(await doc(account.uid,tk,'adminUsers')).enabled===true&&!p.url().includes('/login')});
 if(report.checks.some(v=>!v.ok))throw Error('Access-change assertion failed');report.complete=true;write();console.log(JSON.stringify({complete:true,checks:report.checks.length}));
}catch(e){report.errors.push(e.message);write();console.error(e.message);process.exitCode=1;}finally{if(b)await b.close();}})();
