// Current delivery screenshots in ordinary headless Chrome, without software-renderer flags.
const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('fs'),path=require('path'),root=path.resolve(__dirname,'..');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'}),page=await browser.newPage();const evidence=[];
 for(const [lang,theme,width,height] of [['ar','dark',1440,950],['ar','dark',360,1000],['en','light',1440,950]]){
  await page.setViewportSize({width,height});await page.goto(`http://127.0.0.1:8765/phases/results/02/prototype/index.html?lang=${lang}&theme=${theme}&revision=motion-v2#home`);await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(1000);
  const metrics=await page.evaluate(()=>({renderer:document.querySelector('.sculpture-stage').dataset.renderer,running:document.querySelector('.sculpture-stage').dataset.running,viewport:innerWidth,scroll:document.documentElement.scrollWidth}));
  await page.screenshot({path:path.join(root,'screenshots','motion-v2',`home-${lang}-${theme}-${width}-first-view.png`)});evidence.push({lang,theme,width,height,...metrics});
 }
 await browser.close();fs.writeFileSync(path.join(__dirname,'delivery-preview-results.json'),JSON.stringify(evidence,null,2));console.log(JSON.stringify(evidence));
})().catch(e=>{console.error(e);process.exit(1)});
