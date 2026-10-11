// A short recording of the actual prototype WebGL canvas; not a rendered animation mock.
const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('fs'),path=require('path'),root=path.resolve(__dirname,'..');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const page=await browser.newPage({viewport:{width:1280,height:900}});
 await page.goto('http://127.0.0.1:8765/phases/results/02/prototype/index.html?lang=ar&theme=dark&revision=motion-v2#home');await page.waitForTimeout(900);
 const data=await page.evaluate(async()=>{
   const canvas=document.querySelector('canvas'),stream=canvas.captureStream(30),chunks=[];
   const type=MediaRecorder.isTypeSupported('video/webm;codecs=vp9')?'video/webm;codecs=vp9':'video/webm';
   const recorder=new MediaRecorder(stream,{mimeType:type,videoBitsPerSecond:1800000});
   const done=new Promise(resolve=>{recorder.ondataavailable=e=>{if(e.data.size)chunks.push(e.data)};recorder.onstop=resolve;});
   recorder.start();await new Promise(resolve=>setTimeout(resolve,6500));recorder.stop();await done;stream.getTracks().forEach(track=>track.stop());
   const blob=new Blob(chunks,{type});const bytes=new Uint8Array(await blob.arrayBuffer());let binary='';for(let i=0;i<bytes.length;i+=8192)binary+=String.fromCharCode(...bytes.subarray(i,i+8192));return{base64:btoa(binary),type,size:bytes.length,width:canvas.width,height:canvas.height};
 });
 const target=path.join(root,'screenshots','motion-v2','scene-demo.webm');fs.writeFileSync(target,Buffer.from(data.base64,'base64'));
 await page.setContent('<video muted></video>');const source=fs.readFileSync(target).toString('base64');
 const playback=await page.evaluate(async source=>{const video=document.querySelector('video');video.src='data:video/webm;base64,'+source;await new Promise((resolve,reject)=>{video.onloadeddata=resolve;video.onerror=reject;});await video.play();return{width:video.videoWidth,height:video.videoHeight,ready:video.readyState};},source);
 await browser.close();console.log(JSON.stringify({file:target,mimeType:data.type,bytes:data.size,canvas:{width:data.width,height:data.height},playback}));
})().catch(e=>{console.error(e);process.exit(1)});
