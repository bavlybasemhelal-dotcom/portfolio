// Re-measure the affected contrast checks after supporting short HEX colors.
const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('fs'),path=require('path'),root=path.resolve(__dirname,'..');
function luminance(hex){let n=hex.replace('#','');if(n.length===3)n=n.split('').map(c=>c+c).join('');if(!/^[a-f\d]{6}$/i.test(n))throw new Error('Unmeasurable color '+hex);const v=n.match(/../g).map(h=>parseInt(h,16)/255).map(s=>s<=.04045?s/12.92:((s+.055)/1.055)**2.4);return .2126*v[0]+.7152*v[1]+.0722*v[2]}
function contrast(a,b){const x=luminance(a),y=luminance(b);return(Math.max(x,y)+.05)/(Math.min(x,y)+.05)}
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'}),page=await browser.newPage();
 const report=JSON.parse(fs.readFileSync(path.join(__dirname,'review-results.json'),'utf8'));
 report.contrast=[];report.issues=report.issues.filter(x=>x.type!=='contrast');
 for(const theme of ['light','dark']){
  await page.goto('file:///'+path.join(root,'prototype','index.html').replace(/\\/g,'/')+'?lang=ar&theme='+theme+'#home');
  const tokens=await page.evaluate(()=>{const s=getComputedStyle(document.documentElement);return Object.fromEntries(['bg','surface','raised','ink','muted','primary','on-primary','accent','control','focus','danger','danger-bg','success','success-bg','warning','warning-bg'].map(k=>[k,s.getPropertyValue('--'+k).trim()]));});
  for(const [fg,bg,min] of [['ink','bg',4.5],['ink','surface',4.5],['muted','bg',4.5],['muted','surface',4.5],['muted','raised',4.5],['primary','bg',4.5],['accent','bg',4.5],['on-primary','primary',4.5],['danger','danger-bg',4.5],['success','success-bg',4.5],['warning','warning-bg',4.5],['control','surface',3],['control','bg',3],['focus','surface',3],['focus','bg',3]]){
   const v=contrast(tokens[fg],tokens[bg]),row={theme,fg,bg,foreground:tokens[fg],background:tokens[bg],ratio:+v.toFixed(2),minimum:min,ok:Number.isFinite(v)&&v>=min};report.contrast.push(row);if(!row.ok)report.issues.push({type:'contrast',...row});
  }
 }
 await browser.close();report.summary.issues=report.issues.length;fs.writeFileSync(path.join(__dirname,'review-results.json'),JSON.stringify(report,null,2));fs.writeFileSync(path.join(__dirname,'contrast-results.json'),JSON.stringify(report.contrast,null,2));console.log(JSON.stringify({pairs:report.contrast.length,passed:report.contrast.filter(r=>r.ok).length,minimumText:Math.min(...report.contrast.filter(r=>r.minimum===4.5).map(r=>r.ratio)),issues:report.issues}));
})().catch(e=>{console.error(e);process.exit(1)});
