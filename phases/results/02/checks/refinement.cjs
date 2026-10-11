// Focused checks for the changes made during Phase 02 design review.
const { chromium }=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..');
(async()=>{
 const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});
 const page=await browser.newPage({viewport:{width:1440,height:1000}});
 const base='http://127.0.0.1:8765/phases/results/02/prototype/index.html';
 const results=[];
 await page.goto(base+'?lang=en&theme=light#admin/editor/P001');await page.evaluate(()=>document.fonts.ready);
 const fields=await page.evaluate(()=>({ar:getComputedStyle(document.querySelector('#name-ar')).direction,en:getComputedStyle(document.querySelector('#name-en')).direction}));
 results.push({name:'Independent language-field directions',ok:fields.ar==='rtl'&&fields.en==='ltr',...fields});
 await page.goto(base+'?lang=en&theme=light#states');await page.locator('[data-action="motion"]').click();
 const motion=await page.evaluate(()=>({rootScroll:getComputedStyle(document.documentElement).scrollBehavior,reduced:document.documentElement.dataset.reduced}));
 results.push({name:'Manual reduced motion includes root scroll',ok:motion.rootScroll==='auto'&&motion.reduced==='true',...motion});
 await page.goto(base+'?lang=ar&theme=dark#work');await page.locator('[data-filter="systems"]').click();
 const systems=await page.locator('.project-card').count();await page.locator('#project-search').fill('عنوان غير موجود');const empty=await page.locator('.project-card').count();await page.locator('[data-action="reset-filter"]').click();const all=await page.locator('.project-card').count();
 results.push({name:'Filter, no-results and reset',ok:systems===6&&empty===0&&all===15,systems,empty,all});
 const consistency=await page.locator('.project-card').evaluateAll(es=>[...new Set(es.map(e=>{const s=getComputedStyle(e);return s.borderRadius+'|'+s.padding+'|'+s.borderWidth}))]);
 results.push({name:'Shared card shape/spacing',ok:consistency.length===1,values:consistency});
 await page.goto(base+'?lang=ar&theme=dark#home');const images=await page.evaluate(()=>[...document.images].every(i=>i.complete&&i.naturalWidth>0));
 results.push({name:'Local HTTP preview and logo asset',ok:images});
 await page.setViewportSize({width:1440,height:900});await page.screenshot({path:path.join(root,'screenshots','home-ar-dark-1440-first-view.png'),animations:'disabled'});
 await page.goto(base+'?lang=en&theme=light#admin/editor/P001');await page.setViewportSize({width:360,height:1000});await page.screenshot({path:path.join(root,'screenshots','editor-en-light-360-final.png'),fullPage:true,animations:'disabled'});
 await page.goto(base+'?lang=ar&theme=dark#home');await page.setViewportSize({width:360,height:900});await page.screenshot({path:path.join(root,'screenshots','home-ar-dark-360-first-view.png'),animations:'disabled'});
 await browser.close();fs.writeFileSync(path.join(root,'checks','refinement-results.json'),JSON.stringify(results,null,2));console.log(JSON.stringify(results));
})().catch(e=>{console.error(e);process.exit(1)});
