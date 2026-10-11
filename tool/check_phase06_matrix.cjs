// Read-only layout matrix; each group starts a fresh native Flutter document.
const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path');
const routesOnly=!!process.env.YOGEN_BROWSER_ROUTES_ONLY;
const out=path.resolve(__dirname,'../phases/results/06'),file=path.join(out,routesOnly?'checks/browser-routes.json':'checks/browser-matrix.json');
const report={environment:'Chrome release; live anonymous test-site data; 12 fresh preference contexts',matrix:[],routes:[],errors:[]};
let browser,page,stage='boot';
const routes=['/','/work','/projects/phase06-01','/services','/about','/contact'];
function save(){fs.writeFileSync(file,JSON.stringify(report,null,2));}
async function ready(){for(let i=0;i<150;i++){const h=page.locator('flt-semantics-placeholder');if(await h.count()){await h.focus();await page.keyboard.press('Enter');}if(await page.getByRole('button',{name:'English',exact:true}).or(page.getByRole('button',{name:'العربية',exact:true})).count())return;await page.waitForTimeout(300);}throw Error('Semantics timeout');}
(async()=>{try{
 browser=await chromium.launch({channel:'chrome',headless:true});
 for(const width of (routesOnly?[360]:[360,768,1440]))for(const lang of (routesOnly?['ar']:['ar','en']))for(const theme of (routesOnly?['light']:['light','dark'])){
  const context=await browser.newContext({viewport:{width,height:900},colorScheme:theme});
  await context.addInitScript(theme=>localStorage.setItem('flutter.theme',JSON.stringify(theme)),theme);
  page=await context.newPage();page.on('pageerror',e=>{report.errors.push(stage+': '+e.message);save();});
  stage=`${width} ${lang} ${theme} initial`;
  const data=page.waitForResponse(r=>r.url().includes('/mediaRouting/current')&&r.status()===200,{timeout:60000});
  const base='http://127.0.0.1:8774/?matrix='+Date.now();
  await page.goto(base+'#/?lang='+lang);await ready();await data;
  for(const route of routes){
   stage=`${width} ${lang} ${theme} ${route}`;
   await page.goto(base+'#'+route+'?lang='+lang);await ready();
   if(width===360&&lang==='ar'&&theme==='light'){
    const refreshed=page.waitForResponse(r=>r.url().includes('/mediaRouting/current')&&r.status()===200,{timeout:60000});
    await page.reload();await ready();await refreshed;
    if(!page.url().includes('#'+route+'?lang=ar'))throw Error('Route/language lost on reload');
    report.routes.push({route,lang,refreshed:true,ok:true});save();
   }
   if(route.includes('/projects/'))await page.getByText(lang==='ar'?'مشروع اختبار 01':'Technical project 01',{exact:true}).first().waitFor({timeout:60000});
   if(route==='/work'){
    // Long catalogues scroll; ensure its hydrated result count before capture.
    await page.mouse.move(width/2,500);await page.mouse.wheel(0,600);await page.waitForTimeout(300);
    await page.getByText(lang==='ar'?'29 مشروع':'29 projects',{exact:true}).first().waitFor({timeout:60000});
    await page.mouse.wheel(0,-50000);
   }
   await page.waitForTimeout(650);
   const name=route==='/'?'home':route.includes('projects')?'project':route.slice(1);
   if(!routesOnly)await page.screenshot({path:path.join(out,`screenshots/${name}-${lang}-${theme}-${width}.png`)});
   const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1);
   if(overflow)throw Error('Horizontal browser overflow');
   report.matrix.push({width,lang,theme,route,ok:!report.errors.some(e=>e.startsWith(stage)),horizontalOverflow:false});save();
   console.log(JSON.stringify({captured:report.matrix.length,stage}));
  }
  await context.close();
 }
 if(report.matrix.length!==(routesOnly?6:72)||report.errors.length)throw Error('Incomplete or failed matrix');report.complete=true;save();
}catch(e){report.errors.push(stage+': '+e.message);save();console.error(e.message);process.exitCode=1;}finally{if(browser)await browser.close();}})();
