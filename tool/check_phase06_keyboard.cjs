const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path');const report={checks:[],errors:[]};let browser;
(async()=>{try{
 browser=await chromium.launch({channel:'chrome',headless:true});const p=await browser.newPage({viewport:{width:1440,height:900}});
 await p.goto('http://127.0.0.1:8774/#/work?lang=en&q=Technical%20project%2001');
 for(let i=0;i<150;i++){const h=p.locator('flt-semantics-placeholder');if(await h.count()){await h.focus();await p.keyboard.press('Enter');}if(await p.getByText('1 projects',{exact:true}).count())break;await p.waitForTimeout(300);}
 await p.mouse.move(800,550);await p.mouse.wheel(0,400);await p.waitForTimeout(500);await p.mouse.click(1300,800);
 let found=false;for(let i=0;i<40;i++){await p.keyboard.press('Tab');await p.waitForTimeout(80);const active=await p.evaluate(()=>({text:document.activeElement?.textContent,label:document.activeElement?.getAttribute('aria-label')}));if((active.text||active.label||'').includes('Explore project: Technical project 01')){found=true;break;}}
 if(!found)throw Error('Tab did not reach the project action');report.checks.push({name:'P06-T10 Tab reaches the native project card action',ok:true});
 await p.keyboard.press('Enter');await p.waitForURL('**/projects/phase06-01**',{timeout:10000});report.checks.push({name:'P06-T10 Enter opens the selected project',ok:true});
 report.complete=true;
}catch(e){report.errors.push(e.message);process.exitCode=1;}finally{if(browser)await browser.close();fs.writeFileSync(path.resolve(__dirname,'../phases/results/06/checks/browser-keyboard.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({checks:report.checks.length,errors:report.errors.length}));}})();
