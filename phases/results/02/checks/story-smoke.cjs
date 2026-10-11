const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('fs'),path=require('path'),root=path.resolve(__dirname,'..'),shots=path.join(root,'screenshots','story-v3');fs.mkdirSync(shots,{recursive:true});
(async()=>{const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
 for(const [lang,theme,width] of [['ar','dark',1440],['en','light',1440],['ar','dark',360],['ar','light',360]]){
  await page.setViewportSize({width,height:1000});await page.goto(`http://127.0.0.1:8765/phases/results/02/prototype/index.html?lang=${lang}&theme=${theme}&revision=story-v3#home`);await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(950);
  const metrics=await page.evaluate(()=>({renderer:document.querySelector('.sculpture-stage').dataset.renderer,scrollWidth:document.documentElement.scrollWidth,viewport:innerWidth,projects:document.querySelectorAll('[data-showcase-index]').length,gradient:getComputedStyle(document.body).backgroundImage}));
  await page.screenshot({path:path.join(shots,`home-${lang}-${theme}-${width}.png`)});
  if(width>900){await page.evaluate(()=>window.scrollTo({top:400,behavior:'instant'}));await page.waitForTimeout(300);await page.screenshot({path:path.join(shots,`transition-${lang}-${theme}-${width}.png`)});}
  await page.evaluate(()=>document.querySelector('#featured-work').scrollIntoView({behavior:'instant',block:'start'}));await page.waitForTimeout(700);await page.screenshot({path:path.join(shots,`exhibition-${lang}-${theme}-${width}.png`)});console.log(JSON.stringify({lang,theme,width,...metrics}));
 }console.log(JSON.stringify({errors}));await browser.close();if(errors.length)process.exitCode=1;})().catch(e=>{console.error(e);process.exit(1)});
