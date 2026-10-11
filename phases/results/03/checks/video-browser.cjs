const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path'),root=path.resolve(__dirname,'../../../..');
const config=JSON.parse(fs.readFileSync(path.join(root,'config/drive.phase03.json'),'utf8'));
const report={date:new Date().toISOString(),environment:'Fresh Chrome, no Google login; actual Drive MP4 served as Base64 and played using a Blob in Flutter HtmlElementView',checks:[],errors:[]};
let browser,p;
(async()=>{
 browser=await chromium.launch({channel:'chrome',headless:true});const context=await browser.newContext({viewport:{width:1440,height:1000}});p=await context.newPage();
 report.networkErrors=[];
 p.on('requestfailed',r=>{if(r.url().includes('googlevideo.com'))report.networkErrors.push({host:new URL(r.url()).hostname,error:r.failure()?.errorText});});
 await p.goto('http://127.0.0.1:8766/#/validation/media?video='+config.publicTestVideoId);
 await p.locator('flt-glass-pane').waitFor({state:'attached'});const toggle=p.locator('flt-semantics-placeholder');if(await toggle.count())await toggle.evaluate(e=>e.click());
 await p.getByRole('button',{name:'English',exact:true}).click();
 const cdp=await context.newCDPSession(p);await cdp.send('Performance.enable');
 const heap=async()=> (await cdp.send('Performance.getMetrics')).metrics.find(v=>v.name==='JSHeapUsedSize')?.value;
 report.jsHeapBeforeBytes=await heap();
 await p.getByRole('button',{name:'Load video and play',exact:true}).click();
 await p.getByText(/anonymous_video_loaded:/).waitFor({timeout:70000});
 const element=p.locator('video[aria-label="Drive MP4 video"]');await element.waitFor({timeout:30000});
 report.jsHeapBufferedBytes=await heap();
 await element.scrollIntoViewIfNeeded();
 const box=await element.boundingBox();await p.mouse.click(box.x+box.width/2,box.y+box.height/2);
 let frame;
 for(let attempt=0;attempt<30;attempt++){
   for(const candidate of p.frames())if(await candidate.locator('video').count().catch(()=>0)){frame=candidate;break;}
   if(frame)break;await p.waitForTimeout(1000);
 }
 if(!frame)throw new Error('Drive poster is visible, but no playable video element was found after pressing Play.');
 report.beforePlay=await frame.locator('video').first().evaluate(video=>({duration:Number.isFinite(video.duration)?video.duration:null,readyState:video.readyState,error:video.error?.code||null}));
 await frame.locator('video').first().evaluate(async video=>{video.muted=true;await Promise.race([video.play(),new Promise((_,reject)=>setTimeout(()=>reject(Error('video_play_timeout')),20000))]);});
 await p.waitForTimeout(1500);
 const state=await frame.locator('video').first().evaluate(video=>({duration:video.duration,currentTime:video.currentTime,readyState:video.readyState,error:video.error?.code||null}));
 report.checks.push({name:'Real Drive MP4 bytes play inside Flutter without Google login',ok:state.currentTime>.1&&state.readyState>=2,...state});
 report.jsHeapPlayingBytes=await heap();
 await p.screenshot({path:path.join(root,'phases/results/03/screenshots/video-drive-flutter.png')});
 console.log(JSON.stringify(report.checks));
})().catch(e=>{report.errors.push(e.message);process.exitCode=1;}).finally(async()=>{if(p)await p.screenshot({path:path.join(root,'phases/results/03/screenshots/video-last-state.png')}).catch(()=>{});if(browser)await browser.close();fs.writeFileSync(path.join(__dirname,'video-browser.json'),JSON.stringify(report,null,2));});
