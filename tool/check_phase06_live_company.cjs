// Isolated fixtures: uses the existing local owner vault only inside Dart.
// Keeps anonymous pages open while published company/team data changes.
const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const {spawn}=require('node:child_process'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),out=path.join(root,'phases/results/06/checks');
const report={environment:'Live Firebase/anonymous browser; phase04-test only',checks:[],errors:[]};
let browser;
function check(name,ok){if(!ok)throw Error(name);report.checks.push({name,ok});console.log(name);}
function publish(mode){return new Promise((resolve,reject)=>{
 const command="& 'C:\\dev\\flutter\\bin\\flutter.bat' test test/phase06_cloud_integration_test.dart --dart-define=YOGEN_PHASE06_CLOUD=true --dart-define=YOGEN_PHASE06_COMPANY="+mode+" --concurrency=1 *> phases/results/06/checks/cloud-"+mode+"-console.txt";
 const proc=spawn('powershell.exe',['-NoProfile','-Command',command],{cwd:root,windowsHide:true,stdio:'ignore'});
 proc.on('error',reject);proc.on('exit',code=>code===0?resolve():reject(Error('Cloud '+mode+' failed')));
});}
async function ready(page){for(let i=0;i<150;i++){
 const h=page.locator('flt-semantics-placeholder');if(await h.count()){await h.focus();await page.keyboard.press('Enter');}
 if(await page.getByRole('button',{name:'العربية',exact:true}).count()){await page.getByText('Loading content…',{exact:true}).waitFor({state:'hidden',timeout:60000});return;}
 await page.waitForTimeout(300);
}throw Error('Semantics timeout');}
(async()=>{try{
 browser=await chromium.launch({channel:'chrome',headless:true});const context=await browser.newContext({viewport:{width:1440,height:1000}});
 const about=await context.newPage(),contact=await context.newPage();let navigations=0;
 await about.goto('http://127.0.0.1:8774/#/about?lang=en');await ready(about);
 await contact.goto('http://127.0.0.1:8774/#/contact?lang=en');await ready(contact);
 check('P06-T11 missing profiles/channels hidden initially',await about.getByText('Test profile — not a YOGEN member',{exact:true}).count()===0&&await contact.getByRole('button',{name:'qa@example.com',exact:true}).count()===0);
 for(const p of [about,contact])p.on('framenavigated',frame=>{if(frame===p.mainFrame())navigations++;});
 await publish('on');
 await contact.getByRole('button',{name:'qa@example.com',exact:true}).waitFor({timeout:80000});
 await about.mouse.move(700,650);await about.mouse.wheel(0,450);await about.getByText('Test profile — not a YOGEN member',{exact:true}).waitFor({timeout:80000});
 check('P06-T11 real published profile/contact appear in open pages without reload',navigations===0);
 await about.screenshot({path:path.join(root,'phases/results/06/screenshots/team-live-fixture.png')});
 await publish('off');await contact.getByRole('button',{name:'qa@example.com',exact:true}).waitFor({state:'hidden',timeout:80000});await about.getByText('Test profile — not a YOGEN member',{exact:true}).waitFor({state:'hidden',timeout:80000});
 check('P06-T11 unpublished profile/contact disappear without rebuild',navigations===0);
 report.complete=true;
}catch(e){report.errors.push(e.message);process.exitCode=1;}finally{
 // Restore the fixture even if a browser observation fails.
 if(!report.complete)try{await publish('off');report.fixtureCleanup=true;}catch(e){report.errors.push('Cleanup: '+e.message);}
 if(browser)await browser.close();fs.writeFileSync(path.join(out,'browser-live-company.json'),JSON.stringify(report,null,2));
}})();
