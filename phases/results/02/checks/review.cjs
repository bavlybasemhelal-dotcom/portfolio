// Phase 02 visual-prototype checks only. No Flutter/Firebase/Drive connections.
const { chromium } = require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const shotSubfolder=process.argv[2]||'',shotPrefix='screenshots/'+(shotSubfolder?shotSubfolder+'/':'');
const shots = path.join(root, 'screenshots',shotSubfolder);
fs.mkdirSync(shots, { recursive: true });
const base = 'file:///' + path.join(root, 'prototype', 'index.html').replace(/\\/g, '/');
const routes = { home:'home', work:'work', detail:'project/P008', list:'admin/projects', editor:'admin/editor/P001' };
const report = { matrix:[], extraScreens:[], flows:[], contrast:[], issues:[], browser:'Installed Chrome, headless', kind:'Design-prototype review only' };
function lum(hex) { let normalized=hex.replace('#','');if(normalized.length===3)normalized=normalized.split('').map(c=>c+c).join('');const v=normalized.match(/[a-f\d]{2}/gi).map(n=>parseInt(n,16)/255).map(n=>n<=.04045?n/12.92:((n+.055)/1.055)**2.4);return .2126*v[0]+.7152*v[1]+.0722*v[2]; }
function ratio(a,b) { const x=lum(a),y=lum(b);return (Math.max(x,y)+.05)/(Math.min(x,y)+.05); }
function rgbHex(s) { return '#'+s.match(/[\d.]+/g).slice(0,3).map(n=>Math.round(+n).toString(16).padStart(2,'0')).join(''); }
(async()=>{
  const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});
  report.browserVersion=await browser.version();
  const page=await browser.newPage();
  page.on('pageerror', e=>report.issues.push({type:'script',message:e.message}));
  const open=async(r,lang='ar',theme='dark',width=1440)=>{await page.setViewportSize({width,height:1000});await page.goto(`${base}?lang=${lang}&theme=${theme}#${r}`);await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(900);};
  for(const width of [360,768,1440])for(const lang of ['ar','en'])for(const theme of ['light','dark'])for(const [key,r] of Object.entries(routes)){
    await open(r,lang,theme,width);
    const metrics=await page.evaluate(()=>({viewport:innerWidth,scroll:document.documentElement.scrollWidth,lang:document.documentElement.lang,dir:document.documentElement.dir,theme:document.documentElement.dataset.theme,headings:[...document.querySelectorAll('h1')].map(x=>x.textContent),brokenImages:[...document.images].filter(x=>!x.complete||!x.naturalWidth).length,fontArabic:document.fonts.check('16px "IBM Plex Sans Arabic"'),fontEnglish:document.fonts.check('16px "IBM Plex Sans"')}));
    const filename=`${key}-${lang}-${theme}-${width}.png`;
    await page.screenshot({path:path.join(shots,filename),fullPage:true,animations:'disabled'});
    const activeFontOK=lang==='ar'?metrics.fontArabic:metrics.fontEnglish;
    const ok=metrics.scroll<=width&&metrics.brokenImages===0&&activeFontOK;
    report.matrix.push({screen:key,width,lang,theme,ok,...metrics,screenshot:shotPrefix+filename});
    if(!ok)report.issues.push({type:'layout',screen:key,width,lang,theme,...metrics});
  }
  for(const r of ['services','about','contact','login','admin','admin/media','admin/categories','admin/team','admin/company','admin/accounts','admin/storage','states']){
    for(const [lang,theme,width] of [['ar','dark',1440],['en','light',360]]){
      await open(r,lang,theme,width);
      const metrics=await page.evaluate(()=>({viewport:innerWidth,scroll:document.documentElement.scrollWidth}));
      const filename=`${r.replaceAll('/','-')}-${lang}-${theme}-${width}.png`;
      await page.screenshot({path:path.join(shots,filename),fullPage:true,animations:'disabled'});
      report.extraScreens.push({screen:r,lang,theme,width,...metrics,screenshot:shotPrefix+filename});
      if(metrics.scroll>width)report.issues.push({type:'layout-extra',screen:r,lang,theme,width,...metrics});
    }
  }
  for(const theme of ['light','dark']){
    await open('home','ar',theme);
    const tokens=await page.evaluate(()=>{const s=getComputedStyle(document.documentElement);return Object.fromEntries(['bg','surface','raised','ink','muted','primary','on-primary','accent','control','focus','danger','danger-bg','success','success-bg','warning','warning-bg'].map(k=>[k,s.getPropertyValue('--'+k).trim()]));});
    for(const [fg,bg,min] of [['ink','bg',4.5],['ink','surface',4.5],['muted','bg',4.5],['muted','surface',4.5],['muted','raised',4.5],['primary','bg',4.5],['accent','bg',4.5],['on-primary','primary',4.5],['danger','danger-bg',4.5],['success','success-bg',4.5],['warning','warning-bg',4.5],['control','surface',3],['control','bg',3],['focus','surface',3],['focus','bg',3]]){
      const v=ratio(tokens[fg],tokens[bg]);report.contrast.push({theme,fg,bg,foreground:tokens[fg],background:tokens[bg],ratio:+v.toFixed(2),minimum:min,ok:Number.isFinite(v)&&v>=min});if(!Number.isFinite(v)||v<min)report.issues.push({type:'contrast',theme,fg,bg,ratio:v,min});
    }
  }
  fs.writeFileSync(path.join(root,'checks','review-matrix.json'),JSON.stringify(report,null,2));
  await open('home');
  await page.locator('a[href="#work"]').first().click();
  await page.locator('[data-project="P008"]').click();
  await page.locator('[data-action="similar"]').click();
  const contextOk=await page.locator('#app').innerText().then(s=>s.includes('P008'));
  report.flows.push({name:'Public: home → work → P008 → similar request',ok:contextOk});
  await open('login');await page.locator('#login-form button[type=submit]').click();await page.locator('a[href="#admin/editor/new"]').first().click();
  await page.locator('#summary-ar').fill('عينة لتجربة حفظ المدخلات');await page.locator('[data-action="save-draft"]').click();
  await page.locator('[data-action="preview"]').click();const previewOk=await page.locator('#preview').evaluate(e=>e.open);await page.locator('[data-action="close-preview"]').click();
  await page.locator('[data-action="publish"]').click();const incompleteRejected=await page.locator('#publish-errors').innerText().then(s=>s.length>0);
  await page.locator('[data-action="complete-sample"]').click();await page.locator('[data-action="publish"]').click();
  const publishedMock=await page.locator('#app').innerText().then(s=>s.includes('نسخة منشورة في النموذج'));
  report.flows.push({name:'Admin: login → draft → save → preview → incomplete warning → design sample → mock publish',ok:previewOk&&incompleteRejected&&publishedMock,previewOk,incompleteRejected,publishedMock});
  await open('project/P001');await page.locator('#app [data-action="lightbox"]').click();const dialogOk=await page.locator('#lightbox').evaluate(e=>e.open);await page.locator('[data-action="next-image"]').click();await page.keyboard.press('Escape');
  const closeOk=await page.locator('#lightbox').evaluate(e=>!e.open);const focusReturned=await page.locator('#app [data-action="lightbox"]').evaluate(e=>e===document.activeElement);
  report.flows.push({name:'Gallery: open → next → Escape → trigger focus',ok:dialogOk&&closeOk&&focusReturned,dialogOk,closeOk,focusReturned});
  await open('home');await page.keyboard.press('Tab');const focusMetrics=await page.evaluate(()=>({tag:document.activeElement.tagName,outline:getComputedStyle(document.activeElement).outlineStyle,width:getComputedStyle(document.activeElement).outlineWidth}));
  report.flows.push({name:'Keyboard focus indicator',ok:focusMetrics.outline!=='none'&&parseFloat(focusMetrics.width)>=3,...focusMetrics});
  await page.emulateMedia({reducedMotion:'reduce'});await open('home');const reducedOk=await page.evaluate(()=>window.YogenMotion.reduced()&&document.querySelector('.sculpture-stage').dataset.running==='false'&&document.getAnimations().filter(a=>a.playState==='running').length===0);await page.screenshot({path:path.join(shots,'motion-reduced-ar-dark-1440.png'),fullPage:true});
  report.flows.push({name:'OS reduced motion: scene stopped and UI animations disabled',ok:reducedOk});await page.emulateMedia({reducedMotion:'no-preference'});
  await open('home');await page.locator('[data-action="theme"]').click();await page.locator('[data-action="lang"]').click();
  const switchOk=await page.evaluate(()=>document.documentElement.lang==='en'&&document.documentElement.dir==='ltr'&&document.documentElement.dataset.theme==='light');report.flows.push({name:'Theme & language controls',ok:switchOk});
  await open('home','ar','dark',360);await page.locator('[data-action="menu"]').click();const menuOk=await page.locator('.nav-links').evaluate(e=>getComputedStyle(e).display!=='none');report.flows.push({name:'Mobile navigation disclosure',ok:menuOk});
  await page.setViewportSize({width:375,height:812});await page.screenshot({path:path.join(shots,'home-ar-dark-375-menu.png'),fullPage:true});
  await page.setViewportSize({width:812,height:375});const landscape=await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth);report.flows.push({name:'Phone landscape layout',ok:landscape});
  for(const flow of report.flows)if(!flow.ok)report.issues.push({type:'flow',...flow});
  report.summary={coreScreens:report.matrix.length,extraScreens:report.extraScreens.length,contrastPairs:report.contrast.length,flowChecks:report.flows.length,issues:report.issues.length};
  fs.writeFileSync(path.join(root,'checks','review-results.json'),JSON.stringify(report,null,2));
  await browser.close();console.log(JSON.stringify({summary:report.summary,issues:report.issues}));
})().catch(e=>{report.issues.push({type:'review-script',message:e.message});fs.writeFileSync(path.join(root,'checks','review-results.json'),JSON.stringify(report,null,2));console.error(e);process.exit(1);});
