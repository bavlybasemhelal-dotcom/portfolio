// Check the projected project frame against the following copy in stacked layouts.
const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('fs'),path=require('path');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'}),page=await browser.newPage();
 const cases=[];
 for(const width of [360,601,768,900])for(const lang of ['ar','en'])for(const theme of ['light','dark']){
  await page.setViewportSize({width,height:1000});
  await page.goto(`http://127.0.0.1:8765/phases/results/02/prototype/index.html?lang=${lang}&theme=${theme}&review=spacing#home`);
  await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(700);
  await page.locator('[data-showcase-index="7"]').click();
  await page.evaluate(()=>document.querySelector('#featured-work').scrollIntoView({behavior:'instant',block:'start'}));await page.waitForTimeout(700);
  const metrics=await page.evaluate(()=>{
   const frame=document.querySelector('.showcase-front').getBoundingClientRect(),copy=document.querySelector('.showcase-copy').getBoundingClientRect();
   return {frameBottom:frame.bottom,copyTop:copy.top,gap:copy.top-frame.bottom,scroll:document.documentElement.scrollWidth,viewport:innerWidth};
  });cases.push({width,lang,theme,...metrics,ok:metrics.gap>=12&&metrics.scroll<=metrics.viewport});
 }
 const summary={checks:cases.length,passed:cases.filter(c=>c.ok).length,failed:cases.filter(c=>!c.ok).length};
 fs.writeFileSync(path.join(__dirname,process.argv[2]||'story-spacing-results.json'),JSON.stringify({summary,cases},null,2));
 console.log(JSON.stringify({summary,failed:cases.filter(c=>!c.ok)}));await browser.close();if(summary.failed)process.exitCode=1;
})().catch(e=>{console.error(e);process.exit(1)});
