const { chromium } = require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '../../../..');
const report = { date: new Date().toISOString(), checks: [], errors: [], environment: 'Fresh headless Chromium, local Flutter release build. No Google cookies.' };
const record = (name, ok, extra = {}) => { report.checks.push({name, ok, ...extra}); console.log(JSON.stringify({name,ok,...extra})); };
async function accessible(page) {
  await page.locator('flt-glass-pane').waitFor({state:'attached',timeout:45000});
  const enable = page.locator('flt-semantics-placeholder');
  if (await enable.count()) await enable.evaluate(e => e.click());
  await page.getByRole('button', {name:/^(English|العربية)$/}).waitFor({timeout:30000});
}
let browser, page;
(async () => {
  browser = await chromium.launch({channel:'chrome',headless:true});
  const context = await browser.newContext({viewport:{width:1440,height:900}});
  page = await context.newPage();
  page.on('pageerror', e => report.errors.push(e.message));
  page.on('response', async r => {
    if (r.url().includes('identitytoolkit.googleapis.com')) {
      const data = await r.json().catch(() => ({}));
      report.checks.push({name:'Auth HTTP response',ok:r.ok(),httpStatus:r.status(),error:data.error?.message});
    }
  });
  await page.goto('http://127.0.0.1:8766/'); await accessible(page);
  await page.screenshot({path:path.join(root,'phases/results/03/screenshots/foundation-ar.png')});
  record('Flutter shell rendered', await page.getByRole('button',{name:'English',exact:true}).isVisible());
  await page.getByRole('button',{name:'English',exact:true}).click();
  await page.getByRole('button',{name:'Theme',exact:true}).waitFor();
  record('English switch', true);
  await page.getByRole('button',{name:'Theme',exact:true}).click();
  await page.goto('http://127.0.0.1:8766/#/projects/phase03-fixture');
  await accessible(page);
  await page.getByText('Internal route fixture',{exact:true}).waitFor();
  await page.reload(); await accessible(page); await page.getByText('Internal route fixture',{exact:true}).waitFor();
  record('Deep link survives refresh', page.url().endsWith('#/projects/phase03-fixture'));
  const user = JSON.parse(fs.readFileSync(path.join(root,'.runtime/firebase-test-user.local.json'),'utf8'));
  await page.goto('http://127.0.0.1:8766/#/validation/backend');
  await accessible(page);
  await page.getByRole('textbox',{name:'Email',exact:true}).waitFor();
  await page.getByRole('textbox',{name:'Email',exact:true}).click();
  await page.keyboard.insertText(user.email);
  await page.getByRole('textbox',{name:'Password',exact:true}).click();
  await page.keyboard.insertText(user.password);
  await page.getByRole('button',{name:'Sign in',exact:true}).click();
  await page.getByText('signed_in',{exact:true}).waitFor({timeout:25000});
  record('Real Flutter Firebase SDK sign in', true);
  await page.getByRole('button',{name:'Check Firestore',exact:true}).click();
  await page.getByText(/phase03_checks\/.*\/runs\//).waitFor({timeout:25000});
  record('Real Flutter Firestore server round trip', true);
  await page.screenshot({path:path.join(root,'phases/results/03/screenshots/firebase-sdk.png')});
  await page.getByRole('button',{name:'Sign out',exact:true}).click();
  await page.getByText('signed_out',{exact:true}).waitFor();
  record('Real Flutter Firebase SDK sign out', true);
  await page.goto('http://127.0.0.1:8766/#/validation/scene');
  await accessible(page);
  await page.getByText('A dimensional identity in Flutter',{exact:true}).waitFor();
  await page.screenshot({path:path.join(root,'phases/results/03/screenshots/scene-en-dark.png')});
  await page.getByRole('button',{name:'Pause motion',exact:true}).click();
  await page.getByRole('button',{name:'Resume motion',exact:true}).waitFor();
  record('Native scene pause control', true);
  record('No uncaught browser errors', report.errors.length === 0);
  await browser.close();
})().catch(e => { report.errors.push(e.message); process.exitCode = 1; }).finally(async () => {
  if (page) {
    await page.screenshot({path:path.join(root,'phases/results/03/screenshots/browser-last-state.png')}).catch(()=>{});
    report.lastUiLabels = await page.locator('flt-semantics').evaluateAll(nodes => nodes.map(n=>n.getAttribute('aria-label')||n.textContent).filter(Boolean)).catch(()=>[]);
  }
  if (browser) await browser.close();
  fs.writeFileSync(path.join(__dirname,'browser-smoke.json'), JSON.stringify(report,null,2));
});
