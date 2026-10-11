const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try {
  const page=await browser.newPage(),errors=[],failed=[],scripts=[];
  page.on('pageerror',e=>errors.push(e.message));page.on('requestfailed',r=>failed.push({url:r.url(),error:r.failure()}));
  page.on('response',r=>{if(r.url().endsWith('.js'))scripts.push({url:r.url(),status:r.status()});});
  await page.goto('http://127.0.0.1:8765/phases/results/02/prototype/index.html?lang=en&theme=light&review=load-diagnostic#home');
  await page.waitForTimeout(1000);
  console.log(JSON.stringify({scripts,failed,errors,state:await page.evaluate(()=>({count:document.querySelectorAll('[data-showcase-index]').length,body:document.body.innerText.slice(0,200)}))}));
 }finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
