const {chromium}=require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
(async()=>{const b=await chromium.launch({channel:'chrome',headless:true}),p=await b.newPage();await p.goto('http://127.0.0.1:8770/#/admin/login');await p.locator('flt-semantics-placeholder').waitFor({state:'attached',timeout:60000});
 console.log(await p.locator('flt-semantics-placeholder').evaluate(e=>({html:e.outerHTML,rect:e.getBoundingClientRect().toJSON()})));
 await p.locator('flt-semantics-placeholder').focus();await p.keyboard.press('Enter');await p.waitForTimeout(1000);
 console.log('Semantics count: '+await p.locator('flt-semantics').count());console.log(await p.getByRole('button').allTextContents());console.log(await p.locator('flt-semantics').evaluateAll(nodes=>nodes.map(e=>({role:e.getAttribute('role'),label:e.getAttribute('aria-label'),text:e.textContent}))));
 await b.close();})();
