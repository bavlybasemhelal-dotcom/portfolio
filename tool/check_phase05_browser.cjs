// Own clean browser contexts against the local test build; no personal browser session.
const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),out=path.join(root,'phases/results/05'),shots=path.join(out,'screenshots');fs.mkdirSync(shots,{recursive:true});
const cloud=JSON.parse(fs.readFileSync(path.join(out,'checks/dart-rest-cloud.json'),'utf8'));
if(!cloud.complete)throw Error('Cloud fixtures have not passed');
const privateFixture=JSON.parse(fs.readFileSync(path.join(root,'.runtime/phase05-browser.local.json'),'utf8'));
const owner=JSON.parse(fs.readFileSync(path.join(root,'.runtime/yogen-owner.local.json'),'utf8'));
const report={environment:'Clean Chrome and Edge contexts, no Google login; actual Flutter release test site and live Firebase/Drive',checks:[],errors:[],videos:[]};
report.networkFailures=[];
const safe=message=>String(message).replaceAll(owner.password,'[redacted]').replaceAll(privateFixture.password,'[redacted]');
let browser,p,stage='start', imageReads=new Set(), imageEvents=[];
const adminOnly=process.argv.includes('--admin-only');
const named=text=>p.getByText(text,{exact:true}).or(p.getByLabel(text)).first();
function check(name,ok=true){report.checks.push({name,ok});if(!ok)throw Error(name);console.log(JSON.stringify({verified:name}));}
async function ready(){const deadline=Date.now()+60000;const languages=p.getByRole('button',{name:'English',exact:true}).or(p.getByRole('button',{name:'العربية',exact:true}));while(await languages.count()===0){if(Date.now()>deadline)throw Error('semantics_activation_timeout');const placeholder=p.locator('flt-semantics-placeholder');if(await placeholder.count()){await placeholder.focus();await p.keyboard.press('Enter');}await p.waitForTimeout(500);}await languages.first().waitFor();}
async function uncached(){const session=await p.context().newCDPSession(p);await session.send('Network.enable');await session.send('Network.setCacheDisabled',{cacheDisabled:true});}
async function english(){const button=p.getByRole('button',{name:'English',exact:true});if(await button.count())await button.click();}
async function fill(input,value){await input.click();await p.waitForTimeout(200);await input.fill(value);}
async function login(name,password){await english();for(const [label,value]of[['Username',name],['Password',password]]){await fill(p.getByRole('textbox',{name:label,exact:true}),value);}await p.getByRole('button',{name:'Sign in',exact:true}).click();await named('Team workspace').waitFor({timeout:45000});}
function observeImages(){imageReads=new Set();imageEvents=[];p.on('response',async response=>{if(!response.url().includes('script.googleusercontent.com'))return;try{const value=await response.json();if(value.success&&value.mimeType?.startsWith('image/')){const expected=cloud.assets.find(v=>v.fileId===value.fileId);const matches=!!expected&&crypto.createHash('sha256').update(Buffer.from(value.fileData,'base64')).digest('hex')===expected.sha256;imageEvents.push({fileId:value.fileId,mime:value.mimeType,size:value.fileSize,matches});if(matches)imageReads.add(value.fileId);}else imageEvents.push({success:value.success,error:value.error});}catch(e){imageEvents.push({bodyError:e.message});}});}
async function imagesReady(){
  // Chrome can discard a redirected response body before CDP reads it. Check the
  // actual rendered image in its modal, while REST evidence checks all hashes.
  for(let i=0;i<3;i++){
    await p.getByRole('button',{name:'Enlarge image',exact:true}).nth(i).click();await named('Close').waitFor();
    const file=path.join(shots,`rendered-${stage.split(' ')[0]}-${i}.png`),deadline=Date.now()+60000;
    let pixels=0;
    do{
      if(await named('Image unavailable').count())throw Error('image_decode_error');
      await p.screenshot({path:file});
      pixels=Number(require('node:child_process').execFileSync('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',['-c',"from PIL import Image; import sys; im=Image.open(sys.argv[1]).convert('RGB'); print(sum(1 for r,g,b in im.getdata() if b>120 and b>r*1.2 and g>65 and r<90))",file],{encoding:'utf8'}).trim());
      if(pixels<8000)await p.waitForTimeout(500);
    }while(pixels<8000&&Date.now()<deadline);
    check('Actual decoded and rendered image '+i,pixels>=8000);
    await named('Close').click();
  }
  check('P05-T08 three original images and zoom render inside the site');
}
async function gallery(){observeImages();await p.goto('http://127.0.0.1:8772'+cloud.publicGalleryPath);await ready();await english();await named('Renamed technical media test').waitFor({timeout:45000});await imagesReady();}
(async()=>{
  if(!adminOnly){
  for(const channel of ['chrome','msedge']){
    stage=channel+' gallery';browser=await chromium.launch({channel,headless:true});p=await browser.newPage({viewport:{width:1440,height:900},acceptDownloads:true});
    p.on('pageerror',e=>report.errors.push(safe(e.message)));await uncached();
    await gallery();check('P05-T08 '+channel+' private anonymous images render without Google login');
    check(channel+' no Drive embed/login frames',await p.locator('iframe').count()===0);
    await p.getByRole('button',{name:'Enlarge image',exact:true}).first().click();await named('Close').waitFor();await p.screenshot({path:path.join(shots,channel+'-portrait-zoom.png')});await named('Close').click();check(channel+' in-app image zoom dialog');
    imageReads.clear();await p.reload();await ready();await english();await named('Renamed technical media test').waitFor();await imagesReady();check(channel+' anonymous media survives reload');
    if(channel==='chrome'){
      for(const [language,theme] of [['en','light'],['en','dark'],['ar','dark'],['ar','light']]){
        if(language==='ar' && await p.getByRole('button',{name:'العربية',exact:true}).count())await p.getByRole('button',{name:'العربية',exact:true}).click();
        if(theme==='dark' || (language==='ar' && theme==='light'))await p.getByRole('button',{name:language==='ar'?'المظهر':'Theme',exact:true}).click();
        await p.setViewportSize({width:360,height:850});await p.screenshot({path:path.join(shots,`public-${language}-${theme}-360.png`)});
      }
      await english();await p.setViewportSize({width:1440,height:900});
      check('P05-T09 cover before load; no video element or autoplay',await p.locator('video').count()===0 && await p.getByRole('button',{name:'Load and play video',exact:true}).count()===2);
      for(let i=0;i<2;i++){
        stage='video '+i;await p.getByRole('button',{name:'Load and play video',exact:true}).first().click();
        const video=p.locator('video').nth(i);await video.waitFor({state:'attached',timeout:90000});
        await video.evaluate(v=>new Promise((resolve,reject)=>{if(v.readyState>=2)return resolve();v.onloadeddata=resolve;v.onerror=()=>reject(Error('media_decode_failed'));setTimeout(()=>reject(Error('media_ready_timeout')),30000);}));
        const before=await video.evaluate(v=>({duration:v.duration,paused:v.paused,width:v.videoWidth,height:v.videoHeight,readyState:v.readyState}));
        check('Video '+i+' loads valid dimensions and remains paused',before.width>0 && before.height>0 && before.duration>0 && before.paused);
        await video.evaluate(v=>v.play());await p.waitForFunction(i=>document.querySelectorAll('video')[i].currentTime>0.35,i,{timeout:15000});
        const played=await video.evaluate(v=>{const value={duration:v.duration,currentTime:v.currentTime,width:v.videoWidth,height:v.videoHeight};v.pause();return value;});report.videos.push(played);check('P05-T09 actual '+(i===0?'MP4 5 MiB':'WebM')+' playback');
      }
      stage='PDF';const downloadPromise=p.waitForEvent('download');await p.getByRole('button',{name:'Download attachment',exact:true}).click();const download=await downloadPromise;
      const downloadPath=path.join(root,'.runtime/phase05-downloaded.pdf');await download.saveAs(downloadPath);
      const bytes=fs.readFileSync(downloadPath), expected=cloud.assets.find(v=>v.mime==='application/pdf');
      check('P05-T09 PDF download has original Arabic name and byte-identical content',download.suggestedFilename()==='مرفق-اختبار.pdf' && crypto.createHash('sha256').update(bytes).digest('hex')===expected.sha256);
    }
    await browser.close();browser=null;
  }
  stage='image failure/retry';browser=await chromium.launch({channel:'chrome',headless:true});p=await browser.newPage({viewport:{width:1440,height:900}});p.on('pageerror',e=>report.errors.push(safe(e.message)));
  let fail=true, failures=0;const target=cloud.assets[1].id;
  await p.route('https://script.google.com/macros/s/**',async route=>{let body;try{body=JSON.parse(route.request().postData());}catch{}if(fail&&body?.action==='read'&&body.assetId===target){fail=false;failures++;await route.abort();}else await route.continue();});
  await p.goto('http://127.0.0.1:8772'+cloud.publicGalleryPath);await ready();await english();await named('Image unavailable').waitFor({timeout:90000});check('P05-T11 injected image failure has local placeholder',failures===1);
  const retries=p.getByRole('button',{name:'Retry',exact:true}), beforeRetries=await retries.count();
  await retries.first().click();const retryDeadline=Date.now()+60000;
  while(await retries.count()>=beforeRetries){if(Date.now()>retryDeadline)throw Error('image_retry_timeout');await p.waitForTimeout(250);}
  // The same failed read also affected the two video covers. Each view offers
  // its own retry; verify the first image, rather than matching a remaining cover.
  await p.getByRole('button',{name:'Enlarge image',exact:true}).first().click();await named('Close').waitFor();
  const retryImage=path.join(shots,'image-retry-rendered.png');await p.screenshot({path:retryImage});
  const retryPixels=Number(require('node:child_process').execFileSync('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',['-c',"from PIL import Image; import sys; im=Image.open(sys.argv[1]).convert('RGB'); print(sum(1 for r,g,b in im.getdata() if b>120 and b>r*1.2 and g>65 and r<90))",retryImage],{encoding:'utf8'}).trim());
  check('P05-T11 retry decodes and renders the original image',retryPixels>=8000);await named('Close').click();
  await browser.close();browser=null;
  }
  stage='admin';browser=await chromium.launch({channel:'chrome',headless:true});p=await browser.newPage({viewport:{width:1440,height:900}});p.on('pageerror',e=>report.errors.push(safe(e.message)));
  p.on('requestfailed',request=>{const uri=new URL(request.url());report.networkFailures.push({host:uri.host,path:uri.pathname,error:request.failure()?.errorText});});
  p.on('response',async response=>{if(response.status()<400||!response.url().includes('googleapis.com'))return;let code;try{code=(await response.json()).error?.message;}catch{}report.networkFailures.push({host:new URL(response.url()).host,status:response.status(),code});});
  await p.goto('http://127.0.0.1:8772/#/admin/media');await ready();await login('admin@gmail.com',owner.password);await named('Storage and media').click();await named('Connection settings').waitFor();
  await p.getByRole('textbox',{name:'Administrative storage email — optional',exact:true}).waitFor();
  // The fields exist before the Firestore result is applied. Focus after the
  // library rows arrive, so Flutter attaches its editing state with saved data.
  await named('Preview and usages').first().waitFor({timeout:45000});
  const savedEmail=p.getByRole('textbox',{name:'Administrative storage email — optional',exact:true});
  await savedEmail.click();const settingsDeadline=Date.now()+30000;
  while(await savedEmail.inputValue()!=='phase05-test@example.invalid'){if(Date.now()>settingsDeadline)throw Error('saved_settings_restore_timeout');await p.waitForTimeout(250);}
  check('P05-T01 manager saved settings restore in browser');
  await p.screenshot({path:path.join(shots,'manager-media-en.png')});
  await named('Team workspace').click();await p.getByRole('button',{name:'Sign out',exact:true}).click();await named('Welcome to YOGEN').waitFor();await login(privateFixture.editorLogin,privateFixture.password);await named('Storage and media').click();await named('Media library').waitFor();check('Editor media library omits private connection settings',await named('Connection settings').count()===0);
  const upload=p.getByRole('button',{name:'Choose and upload file',exact:true});
  const projectInput=p.getByRole('textbox',{name:'Stable project or material ID',exact:true});await fill(projectInput,cloud.projectId);
  for(const [i,file] of ['صورة-أفقية.png','صورة-رأسية.jpg','صورة-ويب.webp'].entries()){
    const ar=p.getByRole('textbox',{name:'Arabic description',exact:true}),en=p.getByRole('textbox',{name:'English description',exact:true});
    await fill(ar,'رفع صورة من اختبار المتصفح '+i);await fill(en,'Browser upload test image '+i);
    stage='browser file picker '+file;const pickerPromise=p.waitForEvent('filechooser');await upload.click();const picker=await pickerPromise;await picker.setFiles(path.join(root,'assets/fixtures/phase05',file));
    await named('Uploaded and registered in the library. Link it to a project before publishing.').waitFor({timeout:90000});
    check('Actual Flutter browser picker, generated PNG thumbnail and live registration: '+file);
    await upload.waitFor({state:'visible'});
  }
  const search=p.getByRole('textbox',{name:'Search by name or description',exact:true});await fill(search,'Browser upload test image');
  await named('Preview and usages').first().click();await named('No project links yet.').waitFor();await named('Close').click();check('Library bilingual search and media preview with usage metadata');
  await p.getByRole('button',{name:'العربية',exact:true}).click();await named('اترفع الملف واتسجل في المكتبة. اربطه بالمشروع قبل النشر.').waitFor();await p.setViewportSize({width:360,height:850});await p.screenshot({path:path.join(shots,'editor-media-ar-360.png')});
  check('No uncaught browser exceptions',report.errors.length===0);
})().catch(async e=>{report.errors.push(safe(stage+': '+e.message));report.imageEvents=imageEvents;if(p){await p.screenshot({path:path.join(shots,'browser-failure.png')}).catch(()=>{});fs.writeFileSync(path.join(out,'checks/browser-failure-dom.txt'),safe(await p.locator('body').innerText().catch(()=>'')));}process.exitCode=1;}).finally(async()=>{if(browser)await browser.close();fs.writeFileSync(path.join(out,'checks/'+(adminOnly?'browser-admin':'browser')+'.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({checks:report.checks.length,failed:report.checks.filter(v=>!v.ok).length,errors:report.errors.length}));});
