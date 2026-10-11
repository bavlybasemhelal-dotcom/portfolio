const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),out=path.join(root,'phases/results/07'),base=process.env.YOGEN_PREVIEW_BASE||'http://127.0.0.1:8776';
const owner=JSON.parse(fs.readFileSync(path.join(root,'.runtime/yogen-owner.local.json'),'utf8'));
const config=JSON.parse(fs.readFileSync(path.join(root,'config/firebase.web.json'),'utf8'));
const escape=s=>s.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
async function ready(p){for(let i=0;i<150;i++){const h=p.locator('flt-semantics-placeholder');if(await h.count()){await h.focus();await p.keyboard.press('Enter');}if(await p.getByRole('button',{name:'English',exact:true}).or(p.getByRole('button',{name:'العربية',exact:true})).count())return;await p.waitForTimeout(300);}throw Error('Semantics timeout');}
async function seek(p,loc){if(await loc.count()){await loc.scrollIntoViewIfNeeded({timeout:1500}).catch(()=>{});const b=await loc.boundingBox();if(b&&b.y>=80&&b.y+b.height<p.viewportSize().height-10)return;}await p.mouse.move(Math.min(700,p.viewportSize().width*.65),350);await p.mouse.wheel(0,-50000);await p.waitForTimeout(120);for(let i=0;i<55;i++){
  if(await loc.count()&&await loc.isVisible()){const b=await loc.boundingBox();if(b&&b.y>=80&&b.y+b.height<p.viewportSize().height-10)return;}
  await p.mouse.wheel(0,250);await p.waitForTimeout(120);
}throw Error('Control offscreen: '+loc);}
const text=(p,label)=>p.getByText(label,{exact:true}).first();
const button=(p,label)=>p.getByRole('button',{name:label,exact:true}).first();
const field=(p,label)=>p.getByRole('textbox',{name:new RegExp('^'+escape(label))}).first();
async function click(p,label,role=true){const loc=role?button(p,label):text(p,label).or(p.getByRole('checkbox',{name:label,exact:true})).or(p.getByRole('radio',{name:label,exact:true})).first();await seek(p,loc);await loc.click();await p.waitForTimeout(140);}
async function fill(p,label,value){const f=field(p,label);await seek(p,f);await f.click();await p.waitForTimeout(120);await f.fill(value);}
async function segment(p,label){const items=p.getByRole('button',{name:label,exact:true});await p.mouse.move(Math.min(700,p.viewportSize().width*.65),350);await p.mouse.wheel(0,-50000);await p.waitForTimeout(150);for(let n=0;n<45;n++){for(let i=0;i<await items.count();i++){const item=items.nth(i),box=await item.boundingBox();if(box&&box.y>=80&&box.y+box.height<p.viewportSize().height-10){await item.click();await p.waitForTimeout(150);return;}}await p.mouse.wheel(0,180);await p.waitForTimeout(100);}throw Error('Editor language control unavailable: '+label);}
async function open(p,route,lang='en'){await p.goto(base+'/?qa='+Date.now()+'#'+route+(route.includes('?')?'&':'?')+'lang='+lang);await ready(p);}
async function login(p,account=owner,lang='en'){
  await open(p,'/admin/login',lang);const name=lang==='ar'?'اسم الدخول':'Username';
  if(!await field(p,name).count()){await p.waitForURL('**#/admin**');return;}
  await fill(p,name,account.loginName??account.login);await fill(p,lang==='ar'?'كلمة المرور':'Password',account.password);
  await click(p,lang==='ar'?'تسجيل الدخول':'Sign in');await p.waitForURL(u=>u.hash.startsWith('#/admin')&&!u.hash.startsWith('#/admin/login'),{timeout:60000});
}
async function token(account=owner){const email=account.authEmail??crypto.createHash('sha256').update((account.loginName??account.login).trim().toLowerCase()).digest('hex')+'@login.yogen.invalid';
  const r=await fetch('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key='+config.FIREBASE_API_KEY,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,password:account.password,returnSecureToken:true})});if(!r.ok)throw Error('Test authentication failed');return (await r.json()).idToken;}
function decode(v){if(v.stringValue!==undefined)return v.stringValue;if(v.integerValue!==undefined)return Number(v.integerValue);if(v.booleanValue!==undefined)return v.booleanValue;if(v.nullValue!==undefined)return null;if(v.timestampValue)return v.timestampValue;if(v.arrayValue)return (v.arrayValue.values??[]).map(decode);if(v.mapValue)return Object.fromEntries(Object.entries(v.mapValue.fields??{}).map(([k,v])=>[k,decode(v)]));return v;}
async function doc(id,tk,collection='projectDrafts'){const r=await fetch(`https://firestore.googleapis.com/v1/projects/portfolio-14d15/databases/(default)/documents/sites/phase04-test/${collection}/${id}`,{headers:tk?{Authorization:'Bearer '+tk}:{}});if(r.status===404)return null;if(!r.ok)throw Error('Test document read failed: '+r.status);const v=await r.json();return Object.fromEntries(Object.entries(v.fields).map(([k,v])=>[k,decode(v)]));}
async function saved(p){await p.waitForTimeout(2400);await p.getByText(/Last confirmed save:/).first().waitFor({timeout:60000});for(let i=0;i<100;i++){if(!await p.getByText('Changes not confirmed by the server',{exact:true}).count()&&!await p.getByText('Saving to the server…',{exact:true}).count())return;await p.waitForTimeout(400);}throw Error('Server save unconfirmed');}
async function list(collection,tk){const r=await fetch(`https://firestore.googleapis.com/v1/projects/portfolio-14d15/databases/(default)/documents/sites/phase04-test/${collection}?pageSize=100`,{headers:{Authorization:'Bearer '+tk}});if(!r.ok)throw Error('Test list denied');return ((await r.json()).documents??[]).map(v=>({id:v.name.split('/').pop(),...Object.fromEntries(Object.entries(v.fields).map(([k,v])=>[k,decode(v)]))}));}
module.exports={chromium,fs,path,root,out,base,owner,ready,seek,text,button,field,click,fill,segment,open,login,token,doc,saved,list};
