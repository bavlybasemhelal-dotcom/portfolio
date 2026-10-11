const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../../../..');
const origin=process.argv[2]||'http://127.0.0.1:8766';
const compressed=!origin.endsWith(':8766');
const report={date:new Date().toISOString(),environment:{channel:'Chrome',viewport:'1440×900',downloadMbps:10,uploadMbps:5,latencyMs:80,coldContexts:true,compression:'Python static server, no gzip',renderer:'CanvasKit, release JS build'},loads:[],scene:{},errors:[]};
if(compressed)report.environment.compression='Precompressed gzip responses; local preview only';
async function ready(p){await p.locator('flt-glass-pane').waitFor({state:'attached',timeout:45000});const toggle=p.locator('flt-semantics-placeholder');if(await toggle.count())await toggle.evaluate(e=>e.click());await p.getByRole('button',{name:'English',exact:true}).waitFor({timeout:45000});}
let browser;
(async()=>{
 browser=await chromium.launch({channel:'chrome',headless:true});report.environment.browserVersion=browser.version();
 for(let i=0;i<3;i++){
  const context=await browser.newContext({viewport:{width:1440,height:900}}),p=await context.newPage();
  const cdp=await context.newCDPSession(p);await cdp.send('Network.enable');await cdp.send('Network.setCacheDisabled',{cacheDisabled:true});
  await cdp.send('Network.emulateNetworkConditions',{offline:false,latency:80,downloadThroughput:10*1000*1000/8,uploadThroughput:5*1000*1000/8});
  let bytes=0;cdp.on('Network.loadingFinished',v=>bytes+=v.encodedDataLength);
  const start=Date.now();await p.goto(origin+'/');await ready(p);const usableMs=Date.now()-start;
  const click=Date.now();await p.getByRole('button',{name:'English',exact:true}).click();await p.getByRole('button',{name:'Theme',exact:true}).waitFor();
  await cdp.send('Performance.enable');const metrics=await cdp.send('Performance.getMetrics');
  const used=metrics.metrics.find(v=>v.name==='JSHeapUsedSize')?.value;
  report.loads.push({run:i+1,usableMs,languageResponseMs:Date.now()-click,transferredBytes:bytes,jsHeapBytes:used});
  console.log(JSON.stringify(report.loads.at(-1)));await context.close();
 }
 const context=await browser.newContext({viewport:{width:1440,height:900}}),p=await context.newPage();
 await p.goto(origin+'/#/validation/scene');await ready(p);
 const cadence=await p.evaluate(()=>new Promise(resolve=>{const times=[];let last;const start=performance.now();function frame(now){if(last)times.push(now-last);last=now;if(now-start<5000)requestAnimationFrame(frame);else{times.sort((a,b)=>a-b);resolve({samples:times.length,medianMs:times[Math.floor(times.length*.5)],p95Ms:times[Math.floor(times.length*.95)],over34ms:times.filter(x=>x>34).length});}}requestAnimationFrame(frame);}));
 report.scene.browserRafCadence=cadence;
 await p.mouse.move(700,440);await p.mouse.wheel(0,1500);await p.getByText(/360° \/ 360°/).waitFor();
 report.scene.nativeScrollFullTurn=true;
 await p.getByRole('button',{name:'إيقاف الحركة',exact:true}).click();
 await p.screenshot({path:path.join(root,'phases/results/03/screenshots/native-360-paused.png')});
 await context.close();
 const small=await browser.newContext({viewport:{width:375,height:812},isMobile:true,hasTouch:true,reducedMotion:'reduce'}),phone=await small.newPage();
 await phone.goto(origin+'/#/validation/scene');await ready(phone);
 await phone.screenshot({path:path.join(root,'phases/results/03/screenshots/native-mobile-reduced.png')});
 report.scene.mobileViewport={width:375,height:812,reducedMotion:true,physicalPhone:false};
 await small.close();
})().catch(e=>{report.errors.push(e.message);process.exitCode=1;}).finally(async()=>{if(browser)await browser.close();fs.writeFileSync(path.join(__dirname,compressed?'performance-gzip.json':'performance.json'),JSON.stringify(report,null,2));});
