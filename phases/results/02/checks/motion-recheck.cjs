// Recheck M07 from a fresh page; the prior run had restored a scrolled position.
const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('fs'),path=require('path'),root=path.resolve(__dirname,'..');
(async()=>{
  const resultPath=path.join(__dirname,'motion-results.json');const previous=fs.readFileSync(resultPath,'utf8');
  const historical=path.join(__dirname,'motion-results-before-scroll-reset.json');if(!fs.existsSync(historical))fs.writeFileSync(historical,previous);
  const report=JSON.parse(previous);const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});const page=await browser.newPage({viewport:{width:1440,height:900}});
  await page.goto('http://127.0.0.1:8765/phases/results/02/prototype/index.html?lang=ar&theme=dark&review=scroll-recheck#home');await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(850);
  const before=await page.locator('.feature').first().evaluate(e=>({revealed:e.dataset.revealed||null,scrollY:window.scrollY,top:e.getBoundingClientRect().top,viewport:innerHeight}));
  await page.evaluate(()=>{const target=document.querySelector('.feature');window.observedReveal=null;const observer=new MutationObserver(()=>{if(target.dataset.revealed==='true'){window.observedReveal={revealed:target.dataset.revealed,animations:target.getAnimations().filter(a=>a.playState==='running').length,scrollY:window.scrollY,top:target.getBoundingClientRect().top};observer.disconnect();}});observer.observe(target,{attributes:true,attributeFilter:['data-revealed']});target.scrollIntoView({behavior:'instant',block:'center'});});
  await page.waitForFunction(()=>window.observedReveal!==null,{},{timeout:10000});const after=await page.evaluate(()=>window.observedReveal);
  const check={id:'M07',name:'Sections animate on entering view',ok:before.revealed!=='true'&&before.top>before.viewport&&after.revealed==='true'&&after.animations>0,before,after,recheck:'Fresh navigation and observation of the actual animation start, rather than a fixed timing assumption.'};
  await page.screenshot({path:path.join(root,'screenshots','motion-v2','section-entering.png')});await browser.close();report.checks=report.checks.map(item=>item.id==='M07'?check:item);report.summary={checks:report.checks.length,passed:report.checks.filter(c=>c.ok).length,failed:report.checks.filter(c=>!c.ok).length,scriptErrors:report.errors.length};fs.writeFileSync(resultPath,JSON.stringify(report,null,2));console.log(JSON.stringify({check,summary:report.summary}));if(!check.ok)process.exitCode=1;
})().catch(e=>{console.error(e);process.exit(1)});
