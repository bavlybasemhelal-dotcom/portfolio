const h=require('./phase07_browser_helpers.cjs');const {chromium,fs,path,root,out,owner,ready,seek,text,button,field,click,fill,open,login,token,doc,saved}=h;
const report={environment:'Chrome clean context; actual Flutter editor, Firebase/Drive isolated test site',checks:[],errors:[]};let b,p,stage='boot';
function write(){fs.writeFileSync(path.join(out,'checks/browser-lifecycle.json'),JSON.stringify(report,null,2));}
function check(name,ok=true){report.checks.push({name,ok});write();if(!ok)throw Error(name);console.log(JSON.stringify({verified:name}));}
(async()=>{try{
  b=await chromium.launch({channel:'chrome',headless:true});const ctx=await b.newContext({viewport:{width:1440,height:950},colorScheme:'dark'});
  await ctx.addInitScript(()=>{localStorage.setItem('flutter.language','"en"');localStorage.setItem('flutter.theme','"dark"');localStorage.setItem('flutter.motionPaused','true');});
  p=await ctx.newPage();p.on('pageerror',e=>{report.errors.push(stage+': '+e.message);write();});
  stage='login';await login(p);await text(p,'Team workspace').waitFor();check('P07-T11 manager sign-in opens actual overview');
  const tk=await token();const id='phase07-browser-'+Date.now();report.projectId=id;write();
  stage='incomplete editor';await open(p,`/admin/projects/${id}/edit`);await field(p,'Project title · EN').waitFor({timeout:60000});
  await fill(p,'Project title · EN','Browser managed project');await click(p,'Save draft');await saved(p);check('P07-T03 partial draft confirms real server save',(await doc(id,tk)).content.title.en==='Browser managed project');
  await click(p,'Publish');await text(p,'Missing publication requirements').waitFor();check('P07-T03 publishing incomplete data points to missing fields',await doc(id,null,'projects')===null);
  stage='complete bilingual editor';await fill(p,'Short summary · EN','A complete project created through the admin panel.');await fill(p,'Stable URL name',id);
  const cat=p.getByRole('button',{name:/^Category\s+Choose a category$/});
  // Flutter selects native Material dropdown options through its semantics.
  await seek(p,cat);await cat.click();await p.getByRole('menuitem',{name:'Updated category',exact:true}).click();
  await h.segment(p,'العربية');await fill(p,'Project title · AR','مشروع إدارة من المتصفح');await fill(p,'Short summary · AR','مشروع اختبار كامل من لوحة الأدمن.');
  await click(p,'Details',false);await click(p,'English');await fill(p,'Project description · EN','# Browser heading\nA **formatted** paragraph.\n- First feature\n[Reference](https://example.com)');
  await h.segment(p,'العربية');await fill(p,'Project description · AR','# عنوان من المتصفح\nفقرة **منسقة**\n- وظيفة\n[مرجع](https://example.com)');
  await click(p,'Team and technology',false);await fill(p,'Team contribution · AR','تطوير مشروع اختبار وعرضه.');await click(p,'English');await fill(p,'Team contribution · EN','Built and presented the technical fixture.');await fill(p,'Technologies: one per line, up to 6','Flutter\nFirebase');
  await click(p,'Publication',false);
  for(const [start,label] of [['Usage','Demo'],['Attribution','YOGEN work']]){const box=p.getByRole('button',{name:new RegExp('^'+start+'\\s+Not specified$')});await seek(p,box);await box.click();await p.getByRole('menuitem',{name:label,exact:true}).click();}
  await click(p,'Media',false);await saved(p);
  const assets=['assets/fixtures/phase05/صورة-أفقية.png','assets/fixtures/phase05/صورة-رأسية.jpg','assets/fixtures/phase05/صورة-ويب.webp','.runtime/video-source.mp4'];
  for(let i=0;i<assets.length;i++){
    stage='upload '+i;await click(p,'Upload file');await fill(p,'Arabic description','وصف اختبار '+i);await fill(p,'English description','Fixture description '+i);
    const chooser=p.waitForEvent('filechooser');await button(p,'Select file').click();await (await chooser).setFiles(path.join(root,assets[i]));
    const name=path.basename(assets[i]);let received=false;for(let n=0;n<240;n++){if((await doc(id,tk)).content.mediaIds.length===i+1){received=true;break;}await p.waitForTimeout(500);}if(!received)throw Error('Upload did not reach confirmed project draft');await saved(p);
    check('P07-T01 real editor upload '+name,(await doc(id,tk)).content.mediaIds.length===i+1);
  }
  stage='preview';await click(p,'Preview');await text(p,'Private preview').waitFor();await text(p,'Browser managed project').waitFor({timeout:60000});await p.screenshot({path:path.join(out,'screenshots/private-desktop-preview.png')});
  const heading=p.getByRole('heading',{name:'Browser heading',exact:true});await seek(p,heading);await seek(p,button(p,'Reference'));
  check('P07-T02 same rich project template used by private preview',await heading.count()>0&&await button(p,'Reference').count()>0);await p.screenshot({path:path.join(out,'screenshots/private-rich-body.png')});
  await click(p,'Project card',false);await p.screenshot({path:path.join(out,'screenshots/private-card-preview.png')});await click(p,'Mobile',false);await p.screenshot({path:path.join(out,'screenshots/private-mobile-preview.png')});
  await click(p,'Back to editor');await click(p,'Publish');await text(p,'The server confirmed the new published version.').waitFor({timeout:90000});check('P07-T01 full editor publication and anonymous read',(await doc(id,null,'projects')).assets.length===4);
  stage='reopen';await open(p,`/admin/projects/${id}/edit`);await field(p,'Project title · EN').waitFor();await field(p,'Project title · EN').click();check('P07-T01 title restores after fresh editor reopen',await field(p,'Project title · EN').inputValue()==='Browser managed project');
  await click(p,'Details',false);await fill(p,'Project description · EN','# Edited unpublished body');await saved(p);
  check('P07-T06 draft body cannot alter public snapshot',(await doc(id,null,'projects')).content.body.en.startsWith('# Browser heading'));
  await click(p,'Publish');await text(p,'The server confirmed the new published version.').waitFor();check('P07-T06 republish acknowledged before public changes',(await doc(id,null,'projects')).content.body.en==='# Edited unpublished body');
  stage='offline recovery';await ctx.route('**/firestore.googleapis.com/**',r=>r.abort('internetdisconnected'));
  await fill(p,'Project description · EN','# Offline retained body');await p.waitForTimeout(4500);check('P07-T04 offline save keeps pending state',await text(p,'Changes not confirmed by the server').count()>0);
  await click(p,'All projects');await button(p,'Stay').waitFor();await button(p,'Stay').click();check('P07-T05 unsaved navigation can stay in editor',p.url().includes('/edit'));
  await click(p,'All projects');await button(p,'Leave with recovery').click();await ctx.unroute('**/firestore.googleapis.com/**');
  await open(p,`/admin/projects/${id}/edit`);await button(p,'Recover edits').waitFor({timeout:90000});await button(p,'Recover edits').click();await saved(p);
  check('P07-T04/05 retained local draft resumes and reaches server',(await doc(id,tk)).content.body.en==='# Offline retained body');
  stage='order';await click(p,'Media',false);await click(p,'Set as cover');await saved(p);const ordered=(await doc(id,tk)).content.mediaIds;
  check('P07-T08 explicit cover reorder preserves all files',ordered.length===4&&ordered[0]===(await doc(id,null,'projects')).content.mediaIds[1]);
  await open(p,`/admin/projects?q=${id}`);await text(p,'1 projects').waitFor();await click(p,'Duplicate as draft');await p.waitForURL('**/edit**');const duplicate=p.url().match(/projects\/([^/]+)\/edit/)[1];report.duplicateId=duplicate;write();await field(p,'Project title · EN').waitFor();
  check('P07-T08 UI duplicate draft reuses assets',(await doc(duplicate,tk)).content.mediaIds.join(',')===ordered.join(',')&&(await doc(duplicate,tk)).status==='draft');
  await open(p,`/admin/projects?q=${id}`);await click(p,'Archive');await button(p,'Confirm').click();await p.waitForTimeout(1200);check('P07-T09 UI archive removes public snapshot',await doc(id,null,'projects')===null);
  await click(p,'Restore as draft');await p.waitForTimeout(1200);check('P07-T09 UI restore keeps content and media',(await doc(id,tk)).status==='draft'&&(await doc(id,tk)).content.mediaIds.length===4);
  await p.screenshot({path:path.join(out,'screenshots/project-list-after-lifecycle.png')});
  if(report.errors.length)throw Error('Browser errors were recorded');report.complete=true;write();
}catch(e){report.errors.push(stage+': '+e.message);write();if(p){await p.screenshot({path:path.join(out,'screenshots/lifecycle-failure.png')}).catch(()=>{});fs.writeFileSync(path.join(out,'checks/browser-last-text.txt'),(await p.locator('flt-semantics').allTextContents()).join('\n'));}console.error(stage+': '+e.message);process.exitCode=1;}finally{if(b)await b.close();}})();
