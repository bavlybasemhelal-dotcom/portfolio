const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../../../..'), config=JSON.parse(fs.readFileSync(path.join(root,'config/drive.phase03.json'),'utf8'));
const report={date:new Date().toISOString(),checks:[],errors:[],environment:'Fresh Chrome and Edge, no Google session; actual Flutter release build.'};
const record=(name,ok,extra={})=>{report.checks.push({name,ok,...extra});console.log(JSON.stringify({name,ok,...extra}));};
const url=()=> 'http://127.0.0.1:8766/#/validation/media?bridge='+encodeURIComponent(config.webAppUrl)+'&file='+config.publicTestImageId;
async function ready(p){await p.locator('flt-glass-pane').waitFor({state:'attached'});const toggle=p.locator('flt-semantics-placeholder');if(await toggle.count())await toggle.evaluate(e=>e.click());await p.getByRole('button',{name:/^(English|العربية)$/}).waitFor();}
let browser;
(async()=>{
 for(const channel of ['chrome','msedge']){
  browser=await chromium.launch({channel,headless:true});const context=await browser.newContext({viewport:{width:1440,height:1000}});const p=await context.newPage();
  p.on('pageerror',e=>report.errors.push(e.message));
  await p.goto(url());await ready(p);
  await p.getByRole('button',{name:'English',exact:true}).click();
  await p.getByRole('button',{name:'Display without login',exact:true}).click();
  await p.getByText(/anonymous_image_loaded:/).waitFor({timeout:70000});
  await p.getByRole('img',{name:'Drive test image card',exact:true}).waitFor();
  record(channel+' real anonymous image card and gallery',await p.getByRole('img',{name:'Drive test image gallery',exact:true}).count()===1);
  await p.screenshot({path:path.join(root,'phases/results/03/screenshots/'+channel+'-drive-light.png'),fullPage:true});
  await p.getByRole('button',{name:'Theme',exact:true}).click();await p.reload();await ready(p);
  await p.getByRole('button',{name:'Display without login',exact:true}).click();await p.getByText(/anonymous_image_loaded:/).waitFor({timeout:70000});
  record(channel+' image after refresh and theme change',true);
  await p.screenshot({path:path.join(root,'phases/results/03/screenshots/'+channel+'-drive-dark.png')});
  if(channel==='chrome'){
    await p.goto('http://127.0.0.1:8766/#/validation/backend');await ready(p);
    const user=JSON.parse(fs.readFileSync(path.join(root,'.runtime/firebase-test-user.local.json'),'utf8'));
    await p.getByRole('textbox',{name:'Email',exact:true}).click();await p.keyboard.insertText(user.email);
    await p.getByRole('textbox',{name:'Password',exact:true}).click();await p.keyboard.insertText(user.password);
    await p.getByRole('button',{name:'Sign in',exact:true}).click();await p.getByText('signed_in',{exact:true}).waitFor({timeout:25000});
    await p.goto(url());await ready(p);await p.waitForTimeout(1000);
    const chooser=p.waitForEvent('filechooser');await p.getByRole('button',{name:'Choose and upload',exact:true}).click();
    await (await chooser).setFiles({name:'صورة-اختبار-Flutter.png',mimeType:'image/png',buffer:fs.readFileSync(path.join(root,'assets/fixtures/phase03-test.png'))});
    await p.getByText(/uploaded_and_recorded:/).waitFor({timeout:70000});
    record('Real Flutter file picker → Apps Script → Drive → Firestore',true);
  }
  await browser.close();browser=null;
 }
})().catch(e=>{report.errors.push(e.message);process.exitCode=1;}).finally(async()=>{if(browser)await browser.close();fs.writeFileSync(path.join(__dirname,'media-browser.json'),JSON.stringify(report,null,2));});
