// Clean browser contexts; anonymous Firebase/Drive, no user's browser account.
const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),out=path.join(root,'phases/results/06'),shot=path.join(out,'screenshots');
const cloud=JSON.parse(fs.readFileSync(path.join(out,'checks/cloud-initial.json'),'utf8'));
const phase5=JSON.parse(fs.readFileSync(path.join(root,'phases/results/05/checks/dart-rest-cloud.json'),'utf8'));
const report={environment:'Chrome/Edge clean anonymous contexts; live Firebase/Drive; local Flutter release test site',checks:[],errors:[],matrix:[],requests:[]};
let b,p,stage='boot';const base='http://127.0.0.1:8774';
function save(){fs.writeFileSync(path.join(out,'checks/browser-public.json'),JSON.stringify(report,null,2));}
function check(name,ok=true){report.checks.push({name,ok});save();if(!ok)throw Error(name);console.log(JSON.stringify({verified:name}));}
const named=text=>p.getByText(text,{exact:true}).first();
async function ready(){for(let i=0;i<130;i++){if(await p.getByRole('button',{name:'English',exact:true}).or(p.getByRole('button',{name:'العربية',exact:true})).count())return;const h=p.locator('flt-semantics-placeholder');if(await h.count()){await h.focus();await p.keyboard.press('Enter');}await p.waitForTimeout(350);}throw Error('Semantics timeout');}
async function open(route,lang='en'){const hydrated=stage==='read failure'?Promise.resolve():p.waitForResponse(r=>r.url().includes('/mediaRouting/current')&&r.status()===200,{timeout:60000});await p.goto(base+'/?qa='+Date.now()+'#'+route+(route.includes('?')?'&':'?')+'lang='+lang);await ready();await hydrated;await p.waitForTimeout(500);}
async function bottom(){await p.mouse.move(600,550);await p.mouse.wheel(0,50000);await p.waitForTimeout(400);}
async function seek(locator){await p.mouse.move(220,450);await p.mouse.wheel(0,-50000);await p.waitForTimeout(250);for(let i=0;i<40;i++){if(await locator.count()&&await locator.isVisible()){const box=await locator.boundingBox();if(box&&box.y>=85&&box.y+box.height<885)return;}await p.mouse.wheel(0,300);await p.waitForTimeout(200);}throw Error('Visible control not found: '+locator);}
async function fill(label,value){const f=p.getByRole('textbox',{name:label,exact:true});await seek(f);await f.click();await p.waitForTimeout(200);await f.fill(value);}
function watch(){p.on('pageerror',e=>report.errors.push(stage+': '+e.message));p.on('request',r=>{if(!r.url().includes('script.google.com/macros/s/'))return;try{const body=JSON.parse(r.postData());if(body.action==='read')report.requests.push({stage,assetId:body.assetId,thumbnail:!!body.thumbnail});}catch{}});}
async function decodedGallery(){for(let i=0;i<240;i++){for(const element of await p.locator('flt-semantics[role="img"]').all()){const box=await element.boundingBox();if(box&&box.height>500&&box.x>120&&box.y>100){await p.waitForTimeout(400);return;}}await p.waitForTimeout(400);}throw Error('Modal original image did not render');}
async function zoom(){const button=p.getByRole('button',{name:'Enlarge image',exact:true}).first();await seek(button);await button.click();await p.getByRole('button',{name:'Close',exact:true}).waitFor();await decodedGallery();await p.getByRole('button',{name:'Next image',exact:true}).click();await decodedGallery();await p.screenshot({path:path.join(shot,'anonymous-next-image.png')});check('P06-T06 images zoom/next inside YOGEN, no Google/Drive iframe',await p.locator('iframe').count()===0);await p.keyboard.press('Escape');await p.getByRole('button',{name:'Close',exact:true}).waitFor({state:'hidden'});check('P06-T10 keyboard Escape closes gallery');}
(async()=>{try{
  for(const channel of ['chrome','msedge']){
    stage=channel+' routes';b=await chromium.launch({channel,headless:true});p=await b.newPage({viewport:{width:1440,height:900},colorScheme:'dark',acceptDownloads:true});watch();
    await open('/projects/phase06-01');await named('Technical project 01').waitFor({timeout:60000});await zoom();
    check(channel+' public project direct link/reload');await p.reload();await ready();await named('Technical project 01').waitFor();check(channel+' detail ID survives reload',p.url().includes('/projects/phase06-01'));
    if(channel==='chrome'){
      stage='filter/back';await open('/work?q=Technical%20project%2001&filters='+encodeURIComponent(JSON.stringify(['tag:web','tag:booking'])));await named('1 projects').waitFor({timeout:60000});
      const card=p.getByRole('button',{name:'Explore project: Technical project 01',exact:true});await seek(card);await card.click();await p.waitForURL('**/projects/phase06-01**');check('P06-T01 accessible card opens and route is reflected in URL');
      await p.reload();await ready();await named('Technical project 01').waitFor();await p.getByRole('button',{name:'Back to work',exact:true}).click();await named('1 projects').waitFor();check('P06-T04 reload then explicit Back preserves encoded search and filters',p.url().includes('filters=')&&p.url().includes('q='));await seek(card);await card.click();await p.waitForURL('**/projects/phase06-01**');
      await p.getByRole('button',{name:'العربية',exact:true}).click();await named('مشروع اختبار 01').waitFor();check('P06-T03 project identity survives locale',p.url().includes('phase06-01')&&p.url().includes('lang=ar'));
      await p.goBack();await seek(named('1 projects'));await named('1 projects').waitFor();check('P06-T04 browser back restores search and multi-tag filters',p.url().includes('filters=')&&p.url().includes('q='));
      stage='contact context';await open('/projects/phase06-01');await named('Technical project 01').waitFor();await seek(p.getByRole('button',{name:'Request a similar solution',exact:true}));await p.getByRole('button',{name:'Request a similar solution',exact:true}).click();await p.waitForURL('**/contact**');check('P06-T08 similar solution carries project ID/name',p.url().includes('project=phase06-01')&&p.url().includes('nameEn='));
      await fill('Your name','Browser fixture name');await fill('Project idea and requirements','A retained technical brief');await p.getByRole('button',{name:'العربية',exact:true}).click();
      const field=p.getByRole('textbox',{name:'اسمك',exact:true});await field.click();await p.waitForTimeout(200);check('P06-T08 project reference and fields survive locale',await field.inputValue()==='Browser fixture name'&&p.url().includes('project=phase06-01'));
      stage='media on demand';await open('/work');await named('29 projects').waitFor();check('P06-T07 work never requests video bytes',report.requests.filter(r=>r.stage===stage).every(r=>!phase5.assets.some(a=>a.id===r.assetId&&a.mime.startsWith('video/'))));
      await open('/projects/phase06-01');await named('Technical project 01').waitFor();await seek(p.getByRole('button',{name:'Enlarge image',exact:true}).first());
      check('P06-T07 detail has no automatic video',await p.locator('video').count()===0);
      const videoAlt=phase5.assets.find(a=>a.mime==='video/mp4');
      // Alt descriptions are snapshots from the published source; choose the
      // first video option and then explicitly request its bytes.
      const playOptions=p.getByRole('button').filter({has:p.locator('span')});
      const text=await p.locator('flt-semantics').allTextContents();
      await seek(named('Watch the experience'));const buttons=await p.getByRole('button').allTextContents();fs.writeFileSync(path.join(out,'checks/video-buttons.json'),JSON.stringify(buttons));
      const label=buttons.find(t=>/video|mp4/i.test(t));
      if(!label)throw Error('Video option label not found');await p.getByRole('button',{name:label,exact:true}).click();await p.getByRole('button',{name:'Load and play video',exact:true}).click();
      const v=p.locator('video');await v.waitFor({state:'attached',timeout:90000});await v.evaluate(v=>new Promise((r,j)=>{if(v.readyState>=2)return r();v.onloadeddata=r;v.onerror=()=>j(Error('Video decode'));setTimeout(()=>j(Error('Video timeout')),30000);}));
      check('Video loaded only on request and starts paused',await v.evaluate(v=>v.paused&&v.videoWidth>0));await v.evaluate(v=>v.play());await p.waitForFunction(()=>document.querySelector('video').currentTime>.35);await v.evaluate(v=>v.pause());check('P06-T07 actual playback progresses');
      await seek(p.getByRole('button',{name:'Download attachment',exact:true}));const promise=p.waitForEvent('download');await p.getByRole('button',{name:'Download attachment',exact:true}).click();const download=await promise;const file=path.join(root,'.runtime/phase06-browser.pdf');await download.saveAs(file);
      check('P06-T07 PDF preserves name/content',download.suggestedFilename()==='مرفق-اختبار.pdf'&&crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')===phase5.assets.find(a=>a.mime==='application/pdf').sha256);
      stage='scroll story';await open('/');await p.waitForTimeout(2000);await p.mouse.move(700,500);await p.mouse.wheel(0,1900);await p.waitForTimeout(600);
      await named('1 / 29').waitFor({timeout:10000});await p.mouse.wheel(0,240);await p.waitForTimeout(500);await named('2 / 29').waitFor();check('Scroll selects next project');await p.mouse.wheel(0,-240);await p.waitForTimeout(500);await named('1 / 29').waitFor();check('Reverse scroll selects previous');
      await p.getByRole('button',{name:'Next project',exact:true}).click();await named('2 / 29').waitFor();await p.setViewportSize({width:1366,height:657});await p.waitForTimeout(900);await named('2 / 29').waitFor();await p.screenshot({path:path.join(shot,'compact-story.png')});check('Compact resize retains selected project');
      await p.getByRole('button',{name:'Skip showcase',exact:true}).click();await named('03 / FROM IDEA TO APPLICATION').waitFor();check('Showcase skip exits naturally');
      stage='unpublished';await open('/projects/phase06-private');await named('Project unavailable').waitFor({timeout:45000});check('P06-T05 private/unpublished link reveals no draft',await named('PRIVATE PHASE06 DRAFT').count()===0);
      stage='read failure';let fail=true;await p.route('https://firestore.googleapis.com/**',r=>fail?r.abort():r.continue());await open('/work');await named('Content unavailable').waitFor();fail=false;await p.getByRole('button',{name:'Retry',exact:true}).click();await named('29 projects').waitFor({timeout:60000});check('P06-T05 read error and Retry recover');await p.unroute('https://firestore.googleapis.com/**');
    }
    await b.close();b=null;
  }
  stage='theme';b=await chromium.launch({channel:'chrome',headless:true});p=await b.newPage({viewport:{width:1440,height:900},colorScheme:'dark'});watch();await open('/');check('P06-T02 first visit uses dark system appearance',await p.getByRole('button',{name:'Change theme',exact:true}).count()===1);await p.getByRole('button',{name:'Change theme',exact:true}).click();await p.reload();await ready();check('P06-T02 manual appearance persisted',await p.evaluate(()=>JSON.parse(localStorage.getItem('flutter.theme')))==='light');
  if(!process.env.YOGEN_BROWSER_FUNCTIONAL_ONLY)for(const width of [360,768,1440])for(const lang of ['ar','en'])for(const theme of ['light','dark']){
    await p.setViewportSize({width,height:900});await p.evaluate(theme=>localStorage.setItem('flutter.theme',JSON.stringify(theme)),theme);
    for(const route of ['/','/work','/projects/phase06-01','/services','/about','/contact']){
      stage=`matrix ${width} ${lang} ${theme} ${route}`;await open(route,lang);
      if(route==='/work'){await p.waitForTimeout(3500);await seek(named(lang==='ar'?'29 مشروع':'29 projects'));await p.mouse.wheel(0,-50000);await p.waitForTimeout(250);}
      else if(route.includes('projects'))await named(lang==='ar'?'مشروع اختبار 01':'Technical project 01').waitFor({timeout:60000});
      else if(route==='/')await p.waitForTimeout(300);
      else await p.getByText(lang==='ar'?'جارٍ تحميل المحتوى…':'Loading content…',{exact:true}).waitFor({state:'hidden',timeout:60000});
      await p.waitForTimeout(800);
      const name=route==='/'?'home':route.includes('projects')?'project':route.slice(1);
      await p.screenshot({path:path.join(shot,`${name}-${lang}-${theme}-${width}.png`)});report.matrix.push({width,lang,theme,route,ok:!report.errors.some(e=>e.startsWith(stage))});
    }
  }
  if(!process.env.YOGEN_BROWSER_FUNCTIONAL_ONLY)check('P06-T09 72 browser layouts captured',report.matrix.length===72&&report.matrix.every(v=>v.ok));
  check('No uncaught browser errors',report.errors.length===0);
  report.complete=true;
}catch(e){report.errors.push(stage+': '+e.message);console.error(stage+': '+e.message);process.exitCode=1;}finally{if(b)await b.close();fs.writeFileSync(path.join(out,'checks/browser-public.json'),JSON.stringify(report,null,2));}})();
