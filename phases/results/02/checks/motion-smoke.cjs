// Temporary visual checkpoint for the Phase 02 motion revision; no application services.
const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('fs'),path=require('path'),root=path.resolve(__dirname,'..');
(async()=>{
  fs.mkdirSync(path.join(root,'screenshots','motion-v2'),{recursive:true});
  const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
  for(const [lang,theme,width] of [['ar','dark',1440],['en','light',1440],['ar','dark',360],['ar','light',360]]){
    await page.setViewportSize({width,height:1000});await page.goto(`http://127.0.0.1:8765/phases/results/02/prototype/index.html?lang=${lang}&theme=${theme}#home`);await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(1000);
    const metrics=await page.evaluate(()=>({renderer:document.querySelector('.sculpture-stage').dataset.renderer,triangles:document.querySelector('.sculpture-stage').dataset.triangles,frames:document.querySelector('canvas').dataset.frame,viewport:innerWidth,scroll:document.documentElement.scrollWidth}));
    await page.screenshot({path:path.join(root,'screenshots','motion-v2',`home-${lang}-${theme}-${width}.png`),fullPage:true});console.log(JSON.stringify({lang,theme,width,...metrics}));
  }
  console.log(JSON.stringify({errors}));await browser.close();if(errors.length)process.exitCode=1;
})().catch(e=>{console.error(e);process.exit(1)});
