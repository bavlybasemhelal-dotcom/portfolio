// Default YOGEN build; no fabricated company content or unredacted credentials.
const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path');const root=path.resolve(__dirname,'..'),out=path.join(root,'phases/results/06');
const owner=JSON.parse(fs.readFileSync(path.join(root,'.runtime/yogen-owner.local.json'),'utf8'));
const report={environment:'Default yogen release, clean Chrome, real Firebase',checks:[],errors:[]};let browser,p;
function check(name,ok){if(!ok)throw Error(name);report.checks.push({name,ok});fs.writeFileSync(path.join(out,'checks/final-browser.json'),JSON.stringify(report,null,2));console.log(name);}
async function ready(){for(let i=0;i<150;i++){const h=p.locator('flt-semantics-placeholder');if(await h.count()){await h.focus();await p.keyboard.press('Enter');}if(await p.getByRole('button',{name:'English',exact:true}).or(p.getByRole('button',{name:'العربية',exact:true})).count())return;await p.waitForTimeout(300);}throw Error('Semantics timeout');}
async function open(route){const response=p.waitForResponse(r=>r.url().includes('/sites/yogen/mediaRouting/current')&&r.status()===200,{timeout:60000});await p.goto('http://127.0.0.1:8773/?qa='+Date.now()+'#'+route);await ready();await response;await p.waitForTimeout(400);}
async function seek(locator){await p.mouse.move(800,600);for(let i=0;i<35;i++){if(await locator.count()&&await locator.isVisible())return;await p.mouse.wheel(0,400);await p.waitForTimeout(150);}throw Error('Missing visible content');}
(async()=>{try{
 browser=await chromium.launch({channel:'chrome',headless:true});p=await browser.newPage({viewport:{width:1440,height:900},colorScheme:'dark'});
 p.on('pageerror',e=>report.errors.push(e.message.replaceAll(owner.password,'[redacted]')));
 const publicAuth=[];let track=true;p.on('request',r=>{if(track&&r.url().includes('firestore.googleapis.com')&&!r.url().includes('/adminUsers/'))publicAuth.push(!!r.headers().authorization);});
 await open('/?lang=ar');await p.getByText('أفكارك تستحق',{exact:true}).waitFor();check('Default root is the Arabic public website',!p.url().includes('validation')&&await p.getByText('Isolated test environment — fixtures are not YOGEN client work',{exact:true}).count()===0);
 await p.screenshot({path:path.join(out,'screenshots/final-yogen-home-dark.png')});
 await p.getByRole('button',{name:'تغيير المظهر',exact:true}).click();await p.reload();await ready();check('P06-T02 manual theme and language survive reload',await p.evaluate(()=>JSON.parse(localStorage.getItem('flutter.theme')))==='light'&&p.url().includes('lang=ar'));
 await p.screenshot({path:path.join(out,'screenshots/final-yogen-home-light.png')});
 await open('/work?lang=en');await seek(p.getByText('No published projects yet',{exact:true}));check('P06-T05 real YOGEN catalogue is honestly empty',await p.getByRole('button',{name:/Explore project:/}).count()===0);
 await p.screenshot({path:path.join(out,'screenshots/final-yogen-work-empty.png')});
 await open('/about?lang=en');await p.mouse.wheel(0,450);await p.waitForTimeout(500);check('P06-T11 no invented member profiles',await p.getByText('Our team',{exact:true}).count()===0&&await p.getByText('Test profile — not a YOGEN member',{exact:true}).count()===0);
 await open('/contact?lang=en');check('P06-T11 no fabricated public email/phone',await p.getByRole('button',{name:'qa@example.com',exact:true}).count()===0&&await p.getByText('Contact us directly',{exact:true}).count()===0);
 await seek(p.getByRole('button',{name:'Send request',exact:true}));check('Deferred submission is disabled and honest',await p.getByRole('button',{name:'Send request',exact:true}).isDisabled());check('Public Firestore reads never use an administrator token',publicAuth.length>0&&publicAuth.every(v=>!v));track=false;
 await p.goto('http://127.0.0.1:8773/#/admin/media');await ready();await p.getByRole('textbox',{name:'Username',exact:true}).waitFor();check('Anonymous administrative route still requires login',p.url().includes('/admin/login'));
 for(const [name,value]of[['Username',owner.loginName],['Password',owner.password]]){const input=p.getByRole('textbox',{name,exact:true});await input.click();await p.waitForTimeout(100);await input.fill(value);}
 await p.getByRole('button',{name:'Sign in',exact:true}).click();await p.getByText(/Team workspace/).first().waitFor({timeout:45000});check('Existing independent manager still signs in',true);
 track=true;await open('/work?lang=en');await seek(p.getByText('No published projects yet',{exact:true}));check('Logged-in manager also sees published-only public reads',publicAuth.every(v=>!v));
 check('No uncaught browser errors',report.errors.length===0);report.complete=true;
}catch(e){report.errors.push(e.message.replaceAll(owner.password,'[redacted]'));process.exitCode=1;}finally{if(browser)await browser.close();fs.writeFileSync(path.join(out,'checks/final-browser.json'),JSON.stringify(report,null,2));}})();
