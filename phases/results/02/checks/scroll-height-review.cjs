// Phase 02: regression for direct-file loading and short desktop viewports.
const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('fs'),path=require('path');
const shots=path.resolve(__dirname,'../screenshots/scroll-height-fix');
fs.mkdirSync(shots,{recursive:true});
const report={revision:'scroll-v4-height-fix',checks:[],errors:[],limitations:['Desktop Chrome; viewport and browser display scaling simulated. No physical-phone or Flutter test.']};
const record=(name,ok,evidence)=>{report.checks.push({name,ok,...evidence});console.log(JSON.stringify({name,ok,...evidence}));};
const wait=page=>page.waitForTimeout(700);
const measure=page=>page.evaluate(()=>{
  const track=document.querySelector('.project-scroll-track'),gallery=document.querySelector('.showcase');
  const rect=e=>{const b=e.getBoundingClientRect();return{top:b.top,bottom:b.bottom,left:b.left,right:b.right};};
  return{mode:track.dataset.scrollMode,density:track.dataset.density,start:+track.dataset.start,end:+track.dataset.end,step:+track.dataset.step,
    active:document.querySelector('.project-theatre').dataset.active,href:document.querySelector('.showcase-front').getAttribute('href'),
    gallery:rect(gallery),frame:rect(document.querySelector('.showcase-front')),index:rect(document.querySelector('.exhibition-index')),
    header:document.querySelector('header').getBoundingClientRect().bottom,scrollY,width:innerWidth,height:innerHeight,scrollWidth:document.documentElement.scrollWidth,
    hint:document.querySelector('[data-scroll-hint]').textContent,selectVisible:getComputedStyle(document.querySelector('.scroll-project-select')).display!=='none'};
});
const fits=s=>s.gallery.top>=s.header-2&&s.gallery.bottom<=s.height&&s.scrollWidth===s.width&&s.frame.left>=-2&&s.frame.right<=s.width+2&&s.frame.bottom<=s.index.top-8;
const scroll=async(page,y)=>{await page.evaluate(top=>scrollTo({top,behavior:'instant'}),y);await wait(page);};
const open=async(page,source,lang='ar',theme='dark',size=[1366,657],motion='full')=>{
  await page.setViewportSize({width:size[0],height:size[1]});
  await page.goto((source==='file'?'file:///D:/Projects/Portfolio/phases/results/02/prototype/index.html':'http://127.0.0.1:8765/phases/results/02/prototype/index.html')+`?lang=${lang}&theme=${theme}&motion=${motion}&revision=scroll-v4-height-fix#home`);
  await page.evaluate(()=>document.fonts.ready);await wait(page);
};
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try{
  const page=await browser.newPage();page.on('pageerror',error=>report.errors.push(error.message));page.on('requestfailed',request=>report.errors.push(request.url()+': '+request.failure().errorText));
  for(const size of [[1366,657],[1530,628],[1280,600]])for(const lang of ['ar','en'])for(const theme of ['light','dark']){
   await open(page,'file',lang,theme,size);const initial=await measure(page);await scroll(page,initial.start);const first=await measure(page);
   await page.mouse.move(size[0]/2,size[1]/2);await page.mouse.wheel(0,initial.step);await wait(page);const forward=await measure(page);
   await page.mouse.wheel(0,-initial.step);await wait(page);const back=await measure(page);
   await scroll(page,initial.start+7*initial.step);const longTitle=await measure(page);
   await scroll(page,initial.end);const last=await measure(page);
   const file=`file-${lang}-${theme}-${size.join('x')}.png`;await page.screenshot({path:path.join(shots,file)});
   record('Direct-file wheel and layout '+[lang,theme,size.join('x')].join(' '),initial.mode==='pinned'&&initial.density==='compact'&&first.active==='P001'&&forward.active==='P002'&&back.active==='P001'&&longTitle.active==='P008'&&last.active==='P015'&&last.href==='#project/P015'&&fits(longTitle)&&fits(last),{source:'file',size,lang,theme,first:first.active,forward:forward.active,back:back.active,longTitle,last,screenshot:'screenshots/scroll-height-fix/'+file});
  }
  for(const source of ['file','http']){
   await open(page,source,'ar','dark',[1530,628]);let s=await measure(page);const projects=[];
   for(let i=0;i<15;i++){await scroll(page,s.start+i*s.step);const item=await measure(page);projects.push({active:item.active,href:item.href,ok:item.mode==='pinned'&&item.active==='P'+String(i+1).padStart(3,'0')&&fits(item)});}
   await scroll(page,s.end+400);const after=await measure(page);const processVisible=await page.locator('.process-chapter').evaluate(e=>e.getBoundingClientRect().top<innerHeight);
   record('All projects and natural exit '+source,projects.every(p=>p.ok)&&after.active==='P015'&&after.gallery.top<after.header-100&&processVisible,{source,projects,after,processVisible});
  }
  await open(page,'file','ar','dark',[1530,628]);let s=await measure(page);await scroll(page,s.start+5*s.step);
  const clickHeader=async action=>{const b=await page.locator(`[data-action="${action}"]`).boundingBox();await page.mouse.click(b.x+b.width/2,b.y+b.height/2);await wait(page);};
  await clickHeader('lang');const language=await measure(page);await clickHeader('theme');const theme=await measure(page);
  record('Direct-file compact selection survives language and theme',language.active==='P006'&&theme.active==='P006'&&fits(language)&&fits(theme),{language,theme});
  await page.locator('[data-showcase-step="1"]').press('ArrowRight');const keyboard=await measure(page);const focusedSelect=await page.evaluate(()=>document.activeElement===document.querySelector('.scroll-project-select'));
  await page.locator('.scroll-project-select').selectOption('8');const manual=await measure(page);
  record('Compact controls and keyboard focus',keyboard.active==='P007'&&focusedSelect&&manual.active==='P009',{keyboard,focusedSelect,manual});
  await page.setViewportSize({width:1530,height:1000});await wait(page);const large=await measure(page);await page.setViewportSize({width:1530,height:628});await wait(page);const small=await measure(page);
  record('Resize keeps project and switches density',large.active==='P009'&&large.density==='comfortable'&&small.active==='P009'&&small.density==='compact'&&fits(large)&&fits(small),{large,small});
  await page.locator('[data-showcase-exit]').click();await page.waitForTimeout(1200);const skip=await page.evaluate(()=>({top:document.querySelector('.process-chapter').getBoundingClientRect().top,header:document.querySelector('header').getBoundingClientRect().bottom,focused:document.activeElement===document.querySelector('.process-chapter h2')}));
  record('Compact skip reaches next section',skip.focused&&skip.top>=skip.header-2&&skip.top<skip.header+100,skip);
  await open(page,'file','ar','dark',[1530,628],'reduced');const reduced=await measure(page);await page.locator('[data-showcase-index="14"]').click();const reducedLast=await measure(page);
  record('Reduced motion keeps natural flow and all projects',reduced.mode==='flow'&&reducedLast.active==='P015',{reduced,reducedLast});
  await open(page,'file','ar','dark',[1275,523]);s=await measure(page);await scroll(page,s.start+7*s.step);const scaled=await measure(page);
  record('150-percent-equivalent desktop viewport keeps scroll',scaled.mode==='pinned'&&scaled.active==='P008'&&fits(scaled),scaled);
 }finally{await browser.close();}
 // Browser-level display scaling is separate from the CSS viewport matrix.
 for(const scale of [1.25,1.5]){
  const scaledBrowser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:[`--force-device-scale-factor=${scale}`,'--window-size=1912,785']});
  try{const page=await scaledBrowser.newPage({viewport:null});page.on('pageerror',e=>report.errors.push(e.message));await page.goto('file:///D:/Projects/Portfolio/phases/results/02/prototype/index.html?lang=ar&theme=dark#home');await page.evaluate(()=>document.fonts.ready);await wait(page);const initial=await measure(page);await scroll(page,initial.start);await page.mouse.move(initial.width/2,initial.height/2);await page.mouse.wheel(0,240);await wait(page);const after=await measure(page);record('Browser display scale '+scale,after.mode==='pinned'&&after.active==='P002'&&fits(after),{scale,after});await page.screenshot({path:path.join(shots,`browser-scale-${scale}.png`)});}finally{await scaledBrowser.close();}
 }
 report.summary={checks:report.checks.length,passed:report.checks.filter(c=>c.ok).length,failed:report.checks.filter(c=>!c.ok).length,scriptErrors:report.errors.length};fs.writeFileSync(path.join(__dirname,'scroll-height-results.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report.summary));if(report.summary.failed||report.summary.scriptErrors)process.exitCode=1;
})().catch(error=>{report.errors.push(error.stack);fs.writeFileSync(path.join(__dirname,'scroll-height-results.json'),JSON.stringify(report,null,2));console.error(error);process.exitCode=1;});
