const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path'),root=path.resolve(__dirname,'..');
const report={site:'yogen',environment:'Final release Web, Chrome, actual SDK manager; no test account creation',checks:[],errors:[]};
let browser,p;
const named=(text)=>p.getByText(text,{exact:true}).or(p.getByLabel(text)).first();
function check(name,ok){report.checks.push({name,ok});if(!ok)throw Error(name);}
async function ready(){await p.locator('flt-semantics-placeholder').waitFor({state:'attached',timeout:45000});await p.locator('flt-semantics-placeholder').focus();await p.keyboard.press('Enter');await p.getByRole('button',{name:'English',exact:true}).waitFor();}
(async()=>{
 browser=await chromium.launch({channel:'chrome',headless:true});p=await browser.newPage({viewport:{width:1440,height:900}});p.on('pageerror',e=>report.errors.push(e.message));
 await p.goto('http://127.0.0.1:8771/#/admin/verification');await ready();await named('أهلًا بك في YOGEN').waitFor();check('Final anonymous guard',p.url().endsWith('#/admin/login'));
 await p.getByRole('button',{name:'English',exact:true}).click();
 const owner=JSON.parse(fs.readFileSync(path.join(root,'.runtime/yogen-owner.local.json'),'utf8'));
 for(const [name,value]of[['Username','admin@gmail.com'],['Password',owner.password]]){const input=p.getByRole('textbox',{name,exact:true});await input.click();await input.fill(value);}
 await p.getByRole('button',{name:'Sign in',exact:true}).click();await named('Add an editor account').waitFor({timeout:30000});check('Final yogen site manager login',true);
 await p.getByRole('button',{name:'Theme',exact:true}).click();await p.screenshot({path:path.join(root,'phases/results/04/screenshots/final-manager-en-dark.png')});
 await p.getByRole('button',{name:'العربية',exact:true}).click();await p.getByRole('button',{name:'المظهر',exact:true}).click();await p.setViewportSize({width:360,height:850});await p.screenshot({path:path.join(root,'phases/results/04/screenshots/final-manager-ar-light-360.png')});
 check('No real team identities invented',await named('الحسابات والصلاحيات').count()===1);
 await p.getByRole('button',{name:'تسجيل الخروج',exact:true}).click();await named('أهلًا بك في YOGEN').waitFor();check('Final manager logout',true);check('No browser exceptions',report.errors.length===0);
})().catch(e=>{report.errors.push(e.message);process.exitCode=1;}).finally(async()=>{if(browser)await browser.close();fs.writeFileSync(path.join(root,'phases/results/04/checks/final-browser.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({checks:report.checks.length,failed:report.checks.filter(v=>!v.ok).length,errors:report.errors.length}));});
