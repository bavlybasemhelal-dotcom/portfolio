const h=require('./phase07_browser_helpers.cjs'),crypto=require('node:crypto');
const {chromium,fs,path,out,open,login,text,button,click,ready,field}=h;
const fixture=JSON.parse(fs.readFileSync(path.join(out,'checks/cloud-lifecycle.json'),'utf8')).previewProjectId;
const report={environment:'Chrome, actual Flutter administration, 360/768/1440 px × ar/en × light/dark',states:[],checks:[],errors:[]};let b;
const write=()=>fs.writeFileSync(path.join(out,'checks/browser-matrix.json'),JSON.stringify(report,null,2));
const routes=['/admin','/admin/projects',`/admin/projects/${fixture}/edit`,'/admin/media','/admin/categories','/admin/team','/admin/company','/admin/accounts',`/admin/projects/${fixture}/preview`];
(async()=>{try{b=await chromium.launch({channel:'chrome',headless:true});
 for(const lang of ['ar','en'])for(const theme of ['light','dark']){
  const ctx=await b.newContext({viewport:{width:1440,height:900},colorScheme:theme});
  await ctx.addInitScript(({lang,theme})=>{localStorage.setItem('flutter.language',JSON.stringify(lang));localStorage.setItem('flutter.theme',JSON.stringify(theme));localStorage.setItem('flutter.motionPaused','true');},{lang,theme});
  const p=await ctx.newPage();p.on('pageerror',e=>report.errors.push(`${lang}/${theme}: ${e.message}`));await login(p,undefined,lang);
  for(const width of [360,768,1440]){await p.setViewportSize({width,height:900});await p.waitForTimeout(200);
   for(let i=0;i<routes.length;i++){const route=routes[i];await p.evaluate(v=>location.hash=v,route+'?lang='+lang);await ready(p);await p.waitForTimeout(i===8?2200:1200);
    const loadedControl=i===2?field(p,lang==='ar'?'عنوان المشروع · AR':'Project title · EN'):i===1?field(p,lang==='ar'?'البحث في المشاريع':'Search projects'):i===6?field(p,lang==='ar'?'البريد التجاري (اختياري)':'Business email (optional)'):i===7?field(p,lang==='ar'?'اسم دخول العضو':'Member username'):i===8?text(p,lang==='ar'?'مشروع اختبار معزول':'Isolated editor project'):null;
    if(loadedControl)await loadedControl.waitFor({timeout:60000});else {for(let n=0;n<80&&await p.getByRole('progressbar').count();n++)await p.waitForTimeout(250);}
    await p.mouse.move(width*.7,400);await p.mouse.wheel(0,-50000);await p.waitForTimeout(120);
    const overflow=await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1),ok=!overflow&&p.url().includes(route)&&!await text(p,'Assertion failed').count();
    const state={width,lang,theme,route,ok};report.states.push(state);write();if(!ok)throw Error('Invalid route/overflow: '+JSON.stringify(state));
    await p.screenshot({path:path.join(out,`screenshots/matrix-${lang}-${theme}-${width}-${i}.png`)});
   }
  }
  if(lang==='en'&&theme==='dark'){
   await p.evaluate(()=>location.hash='/admin?lang=en');await p.waitForTimeout(1200);
   const nav=button(p,'Projects');await nav.focus();await p.keyboard.press('Enter');await p.waitForTimeout(1000);report.checks.push({name:'P07-T12 sidebar is exposed to semantics and keyboard navigation',ok:p.url().includes('/admin/projects')});
   await click(p,'Resume motion');await button(p,'Pause motion').waitFor();await p.mouse.move(700,350);await p.mouse.wheel(0,-50000);await p.waitForTimeout(250);await p.mouse.move(1420,30);const a=await p.screenshot();await p.waitForTimeout(1200);const z=await p.screenshot();report.checks.push({name:'P07-T12 3D/background scene visibly animates',ok:crypto.createHash('sha256').update(a).digest('hex')!==crypto.createHash('sha256').update(z).digest('hex')});await click(p,'Pause motion');await button(p,'Resume motion').waitFor();report.checks.push({name:'P07-T12 global motion pause can be restored',ok:true});
  }
  await ctx.close();
 }
 if(report.errors.length||report.checks.some(v=>!v.ok))throw Error('Matrix/browser checks failed');report.complete=true;write();console.log(JSON.stringify({states:report.states.length,checks:report.checks.length,complete:true}));
}catch(e){report.errors.push(e.message);write();console.error(e.message);process.exitCode=1;}finally{if(b)await b.close();}})();
