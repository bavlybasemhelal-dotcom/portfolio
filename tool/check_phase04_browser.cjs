const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'), out=path.join(root,'phases/results/04');
fs.mkdirSync(path.join(out,'screenshots'),{recursive:true});
const report={date:new Date().toISOString(),environment:'Chrome, actual Flutter release, Auth SDK and cloud Firestore; isolated phase04-test',checks:[],errors:[]};
function check(name,ok){report.checks.push({name,ok});console.log(JSON.stringify({name,ok}));if(!ok)throw Error(name);}
function named(p,text){return p.getByText(text,{exact:true}).or(p.getByLabel(text,{exact:false})).first();}
async function ready(p){await p.locator('flt-glass-pane').waitFor({state:'attached',timeout:60000});const toggle=p.locator('flt-semantics-placeholder');await toggle.waitFor({state:'attached',timeout:15000}).catch(()=>{});if(await toggle.count()){await toggle.focus();await p.keyboard.press('Enter');}await p.getByRole('button',{name:/^(English|العربية)$/}).waitFor({timeout:45000});}
async function fill(p,name,value){const field=p.getByRole('textbox',{name,exact:true});await field.click();await field.fill(value);}
let browser,p;
(async()=>{
 browser=await chromium.launch({channel:'chrome',headless:true});const context=await browser.newContext({viewport:{width:1440,height:900}});p=await context.newPage();p.on('pageerror',e=>report.errors.push(e.message));
 await p.goto('http://127.0.0.1:8770/#/admin/verification');await ready(p);await named(p,'أهلًا بك في YOGEN',{exact:true}).waitFor();check('Protected deep link redirects anonymous visitor',p.url().endsWith('#/admin/login'));
 await p.screenshot({path:path.join(out,'screenshots/login-ar-light.png')});await p.getByRole('button',{name:'English',exact:true}).click();await named(p,'Welcome to YOGEN',{exact:true}).waitFor();await p.getByRole('button',{name:'Theme',exact:true}).click();
 await fill(p,'Username','admin@gmail.com');await fill(p,'Password','Wrong-test-password-123');await p.getByRole('button',{name:'Sign in',exact:true}).click();await named(p,'The username or password is incorrect.',{exact:true}).waitFor({timeout:30000});check('Wrong credentials show readable error',true);
 const owner=JSON.parse(fs.readFileSync(path.join(root,'.runtime/yogen-owner.local.json'),'utf8'));
 await fill(p,'Password',owner.password);await p.getByRole('button',{name:'Sign in',exact:true}).click();await named(p,'Add an editor account',{exact:true}).waitFor({timeout:30000});check('Actual Firebase SDK owner login with role',true);
 await p.reload();await ready(p);await named(p,'Add an editor account',{exact:true}).waitFor({timeout:30000});check('Protected URL restores SDK session after reload',p.url().endsWith('#/admin/verification'));
 const name='browser-fixture-'+Date.now(), password='Fixture-Only-'+require('node:crypto').randomBytes(24).toString('hex');
 await fill(p,'Member username',name);await fill(p,'Member password',password);await p.getByRole('button',{name:'Add editor',exact:true}).click();await named(p,'Editor added. The manager session is unchanged.',{exact:true}).waitFor({timeout:40000});check('Manager provisions editor without replacing own SDK session',await named(p,'Add an editor account',{exact:true}).isVisible());
 fs.writeFileSync(path.join(root,'.runtime/phase04-browser-fixture.local.json'),JSON.stringify({login:name,password}));
 await p.screenshot({path:path.join(out,'screenshots/manager-en-dark.png')});
 for(const width of[360,768]){await p.setViewportSize({width,height:850});await p.screenshot({path:path.join(out,`screenshots/manager-en-dark-${width}.png`)});check('Manager forms remain available at '+width,await p.getByRole('textbox',{name:'Member username',exact:true}).count()===1);}
 await p.setViewportSize({width:1440,height:900});await p.getByRole('button',{name:'Sign out',exact:true}).click();await named(p,'Welcome to YOGEN',{exact:true}).waitFor();check('Logout returns to guarded login',p.url().endsWith('#/admin/login'));
 await fill(p,'Username',name);await fill(p,'Password',password);await p.getByRole('button',{name:'Sign in',exact:true}).click();await named(p,'Team workspace',{exact:true}).waitFor({timeout:30000});check('Editor enters workspace without account management',await named(p,'Add an editor account',{exact:true}).count()===0);
 const fixture=JSON.parse(fs.readFileSync(path.join(root,'.runtime/phase04-cloud-fixtures.local.json'),'utf8'));
 const sign=await fetch('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key='+fixture.apiKey,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:owner.email,password:owner.password,returnSecureToken:true})});const signed=await sign.json();
 const base='https://firestore.googleapis.com/v1/projects/portfolio-14d15/databases/(default)/documents', headers={'Content-Type':'application/json','Authorization':'Bearer '+signed.idToken};
 const rows=await(await fetch(base+'/sites/phase04-test:runQuery',{method:'POST',headers,body:JSON.stringify({structuredQuery:{from:[{collectionId:'adminUsers'}],where:{fieldFilter:{field:{fieldPath:'loginName'},op:'EQUAL',value:{stringValue:name}}}}})})).json();const doc=rows.find(v=>v.document)?.document;if(!doc)throw Error('Browser fixture role missing');
 const revoke=await fetch(base+':commit',{method:'POST',headers,body:JSON.stringify({writes:[{update:{name:doc.name,fields:{...doc.fields,enabled:{booleanValue:false},updatedBy:{stringValue:owner.uid}}},updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]}]})});if(!revoke.ok)throw Error('Revocation request failed');
 await named(p,'Welcome to YOGEN',{exact:true}).waitFor({timeout:35000});check('Revoked editor leaves protected screen on role refresh',p.url().endsWith('#/admin/login'));
 await p.getByRole('button',{name:'Sign out current account',exact:true}).click();await p.getByRole('button',{name:'Recover access',exact:true}).click();await named(p,'This account uses a username independent of email. Contact the YOGEN project owner to recover access.',{exact:true}).waitFor();check('Recovery uses project owner and sends no email',true);
 check('No uncaught browser errors',report.errors.length===0);
})().catch(e=>{report.errors.push(e.message);process.exitCode=1;}).finally(async()=>{if(p)await p.screenshot({path:path.join(out,'screenshots/browser-last-state.png')}).catch(()=>{});if(browser)await browser.close();fs.writeFileSync(path.join(out,'checks/browser-cloud.json'),JSON.stringify(report,null,2));});

