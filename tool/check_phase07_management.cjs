const h=require('./phase07_browser_helpers.cjs'),crypto=require('node:crypto');const {chromium,fs,path,root,out,ready,seek,text,button,field,click,fill,open,login,token,doc,list}=h;
const report={environment:'Chrome manager/editor, actual accounts/category/profile/contact controls in isolated site',checks:[],errors:[]};let b,p,stage='boot';
function write(){fs.writeFileSync(path.join(out,'checks/browser-management.json'),JSON.stringify(report,null,2));}
function check(name,ok=true){report.checks.push({name,ok});write();if(!ok)throw Error(name);console.log(JSON.stringify({verified:name}));}
async function segment(label){await h.segment(p,label);}
async function settleDoc(id,collection,test,tk){for(let i=0;i<100;i++){const v=await doc(id,tk,collection);if(test(v))return v;await p.waitForTimeout(250);}throw Error('Server state not confirmed');}
(async()=>{try{
 b=await chromium.launch({channel:'chrome',headless:true});const ctx=await b.newContext({viewport:{width:1440,height:950},colorScheme:'light'});await ctx.addInitScript(()=>{localStorage.setItem('flutter.language','"en"');localStorage.setItem('flutter.theme','"light"');localStorage.setItem('flutter.motionPaused','true');});p=await ctx.newPage();p.on('pageerror',e=>{report.errors.push(stage+': '+e.message);write();});await login(p);const tk=await token();
 stage='categories';await open(p,'/admin/categories');await click(p,'Add category');const cat='phase07-ui-'+Date.now();report.categoryId=cat;write();
 await fill(p,'Stable identifier',cat);await fill(p,'Arabic name','تصنيف من اللوحة');await fill(p,'English name','UI category');await fill(p,'Order','12');await p.getByRole('switch',{name:'Available for publishing',exact:true}).click();await button(p,'Save category').click();
 await settleDoc(cat,'categories',v=>v?.enabled===true,tk);check('P07-T10 UI creates bilingual enabled category with stable ID');
 await open(p,`/admin/projects?category=${cat}`);await text(p,'0 projects').waitFor();check('P07-T10 category filter applies to project list');
 stage='profiles';await open(p,'/admin/team');await click(p,'Add team profile');await segment('العربية');await fill(p,'Name · AR','ملف جزئي من اللوحة');await button(p,'Save draft').click();await text(p,'The server confirmed the draft.').waitFor();
 const partial=(await list('teamDrafts',tk)).find(v=>v.name.ar==='ملف جزئي من اللوحة');report.profileId=partial.id;write();check('P07-T13 partial profile is persisted and hidden',await doc(partial.id,null,'team')===null);

 // Search the intended profile via its name and then the adjacent action if other test profiles precede it.
 await segment('العربية');await fill(p,'Name · AR','عضو واجهة اختبار');await fill(p,'Role · AR','مطور اختبار');await segment('English');await fill(p,'Name · EN','UI fixture member');await fill(p,'Role · EN','Fixture developer');await fill(p,'Display order','0');
 await button(p,'Save and show').click();await text(p,'The server confirmed the visible profile.').waitFor({timeout:60000});await button(p,'Close').click();
 const published=(await list('team',tk)).find(v=>v.name.en==='UI fixture member');report.profileId=published.id;check('P07-T13 complete bilingual profile becomes visible in server order',published.order===0);
 await open(p,'/about');await text(p,'UI fixture member').waitFor({timeout:60000});check('P07-T13 public About reads new profile without rebuild');
 stage='company';await open(p,'/admin/company');await fill(p,'Business email (optional)','panel@example.com');await fill(p,'International WhatsApp, e.g. +201234567890','+201234567890');await click(p,'Save and update website');await text(p,'The server confirmed the website update.').waitFor();
 check('P07-T14 validated email and WhatsApp are saved from UI',(await doc('current',null,'company')).contacts.email==='panel@example.com');
 await open(p,'/contact');await text(p,'panel@example.com').waitFor({timeout:60000});check('P07-T14 public contact reads manager changes without rebuild');
 await open(p,'/admin/company');await fill(p,'Business email (optional)','bad');await click(p,'Save and update website');await text(p,'Enter a valid value or leave it empty.').waitFor();check('P07-T14 invalid channel rejected beside field without changing server',(await doc('current',null,'company')).contacts.email==='panel@example.com');
 await fill(p,'Business email (optional)','');await fill(p,'International WhatsApp, e.g. +201234567890','');await click(p,'Save and update website');await text(p,'The server confirmed the website update.').waitFor();check('P07-T14 blank channels removed from public snapshot',Object.keys((await doc('current',null,'company')).contacts).length===0);
 stage='accounts';await open(p,'/admin/accounts');const name='phase07-ui-member-'+Date.now(),password='Yogen-UI-'+crypto.randomUUID();await fill(p,'Member username',name);await fill(p,'Member password',password);await click(p,'Add editor');await text(p,'Editor added. The manager session is unchanged.').waitFor({timeout:90000});
 const account=(await list('adminUsers',tk)).find(v=>v.loginName===name);const localFile=path.join(root,'.runtime/phase07-accounts.local.json');const local=JSON.parse(fs.readFileSync(localFile,'utf8'));local.accounts.push({uid:account.uid,login:name,password});fs.writeFileSync(localFile,JSON.stringify(local));
 await seek(p,field(p,'Member password'));await field(p,'Member password').click();await p.waitForTimeout(200);check('P07-T11 UI creation preserves manager session and clears password',await field(p,'Member password').inputValue()==='');
 check('P07-T11 new account has enabled editor role',account.role==='editor'&&account.enabled===true);
 stage='editor access';const memberCtx=await b.newContext({viewport:{width:1440,height:950}});await memberCtx.addInitScript(()=>{localStorage.setItem('flutter.language','"en"');localStorage.setItem('flutter.motionPaused','true');});const member=await memberCtx.newPage();await login(member,{login:name,password});
 await open(member,'/admin/accounts');await text(member,'Team workspace').waitFor();check('P07-T07 direct manager page is guarded for editor',!member.url().includes('/accounts'));
 await open(member,'/admin/media');await text(member,'Storage and media').waitFor();check('P07-T07 editor library hides storage connection settings',await member.getByText('Save storage settings',{exact:true}).count()===0);
 await memberCtx.close();await p.screenshot({path:path.join(out,'screenshots/accounts-after-management.png')});
 if(report.errors.length)throw Error('Recorded browser errors');report.complete=true;write();
 }catch(e){report.errors.push(stage+': '+e.message);write();if(p){await p.screenshot({path:path.join(out,'screenshots/management-failure.png')}).catch(()=>{});fs.writeFileSync(path.join(out,'checks/management-last-text.txt'),(await p.locator('flt-semantics').allTextContents()).join('\n'));}console.error(stage+': '+e.message);process.exitCode=1;}finally{if(b)await b.close();}})();
