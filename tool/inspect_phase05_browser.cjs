const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path'),root=path.resolve(__dirname,'..');
let browser,p;
(async()=>{
 const report=JSON.parse(fs.readFileSync(path.join(root,'phases/results/05/checks/dart-rest-cloud.json'),'utf8'));
 browser=await chromium.launch({channel:'chrome',headless:true});p=await browser.newPage({viewport:{width:1440,height:900}});const requests=[];
 p.on('response',r=>{if(r.url().includes('google'))requests.push({host:new URL(r.url()).host,status:r.status()});});
 await p.goto('http://127.0.0.1:8772'+report.publicGalleryPath);
 await p.locator('flt-semantics-placeholder').waitFor({timeout:45000});await p.locator('flt-semantics-placeholder').focus();await p.keyboard.press('Enter');
 await p.getByRole('button',{name:'English',exact:true}).click();await p.getByText('Renamed technical media test',{exact:true}).waitFor();
 await p.waitForTimeout(12000);
 const value=await p.evaluate(()=>({text:document.body.innerText,semantics:Array.from(document.querySelectorAll('flt-semantics')).map(v=>({role:v.getAttribute('role'),label:v.getAttribute('aria-label'),text:v.innerText.slice(0,100)}))}));
 await p.screenshot({path:path.join(root,'phases/results/05/screenshots/gallery-inspect.png')});
 fs.writeFileSync(path.join(root,'phases/results/05/checks/gallery-inspect.json'),JSON.stringify({requests,...value},null,2));
 console.log(JSON.stringify({requests,roles:value.semantics.map(v=>v.role).filter(Boolean)}));await browser.close();
})().catch(async e=>{console.log('Inspection failed: '+e.message);if(p){console.log((await p.locator('body').innerText()).slice(0,4500));await p.screenshot({path:path.join(root,'phases/results/05/screenshots/gallery-inspect-error.png')});}process.exitCode=1;}).finally(async()=>{if(browser)await browser.close();});
