// Final yogen build, clean context. Credentials remain in the private runtime file.
const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),out=path.join(root,'phases/results/05');
const owner=JSON.parse(fs.readFileSync(path.join(root,'.runtime/yogen-owner.local.json'),'utf8'));
const drive=JSON.parse(fs.readFileSync(path.join(root,'config/drive.phase05.json'),'utf8'));
const report={site:'yogen',environment:'Actual final Flutter release, clean Chrome and live Firebase',checks:[],errors:[]};
let browser,p;
const named=text=>p.getByText(text,{exact:true}).or(p.getByLabel(text)).first();
function check(name,ok){report.checks.push({name,ok});if(!ok)throw Error(name);console.log(JSON.stringify({verified:name}));}
(async()=>{
  browser=await chromium.launch({channel:'chrome',headless:true});p=await browser.newPage({viewport:{width:1440,height:900}});
  p.on('pageerror',e=>report.errors.push(e.message.replaceAll(owner.password,'[redacted]')));
  await p.goto('http://127.0.0.1:8773/#/admin/media');
  const deadline=Date.now()+60000;
  const languages=p.getByRole('button',{name:'English',exact:true}).or(p.getByRole('button',{name:'العربية',exact:true}));
  while(await languages.count()===0){if(Date.now()>deadline)throw Error('semantics_activation_timeout');const placeholder=p.locator('flt-semantics-placeholder');if(await placeholder.count()){await placeholder.focus();await p.keyboard.press('Enter');}await p.waitForTimeout(500);}
  if(await p.getByRole('button',{name:'English',exact:true}).count())await p.getByRole('button',{name:'English',exact:true}).click();
  await named('Welcome to YOGEN').waitFor();check('Anonymous media route requires team login',p.url().includes('/admin/login'));
  for(const [label,v]of[['Username','admin@gmail.com'],['Password',owner.password]]){const input=p.getByRole('textbox',{name:label,exact:true});await input.click();await p.waitForTimeout(200);await input.fill(v);}
  await p.getByRole('button',{name:'Sign in',exact:true}).click();await named('Team workspace').waitFor({timeout:45000});
  await named('Storage and media').click();await named('Connection settings').waitFor();check('Original independent manager opens the protected media library',true);
  await named('No media matches this search.').waitFor({timeout:30000});
  const endpoint=p.getByRole('textbox',{name:'Apps Script Web App URL',exact:true});
  const email=p.getByRole('textbox',{name:'Administrative storage email — optional',exact:true});
  await endpoint.click();const settingsDeadline=Date.now()+30000;
  while(await endpoint.inputValue()!==drive.webAppUrl){if(Date.now()>settingsDeadline)throw Error('saved_settings_restore_timeout');await p.waitForTimeout(250);}
  await email.click();check('Saved live connection restored; administrative email deferred',await email.inputValue()==='');
  await named('No media matches this search.').waitFor({timeout:30000});
  const search=p.getByRole('textbox',{name:'Search by name or description',exact:true});await search.click();
  check('Final yogen space contains no test media and no uncaught exceptions',report.errors.length===0 && await search.inputValue()==='' && await named('The operation could not finish. Check connectivity and access, or recover the pending upload.').count()===0);
  await p.screenshot({path:path.join(out,'screenshots/final-yogen-media.png')});
})().catch(async e=>{report.errors.push(String(e.message).replaceAll(owner.password,'[redacted]'));if(p)await p.screenshot({path:path.join(out,'screenshots/final-browser-failure.png')}).catch(()=>{});process.exitCode=1;})
.finally(async()=>{if(browser)await browser.close();fs.writeFileSync(path.join(out,'checks/final-browser.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({checks:report.checks.length,errors:report.errors.length}));});
