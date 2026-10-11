// Record a small generated canvas fixture; no user media or Google browser session.
const fs = require('node:fs'), path = require('node:path');
const { chromium } = require('C:/Users/Dell/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root = path.resolve(__dirname, '..');
(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  try {
    const page = await browser.newPage();
    const result = await page.evaluate(async () => {
      const canvas = document.createElement('canvas'); canvas.width = 320; canvas.height = 180;
      const context = canvas.getContext('2d'), stream = canvas.captureStream(15);
      const mime = 'video/webm;codecs=vp8';
      if (!MediaRecorder.isTypeSupported(mime)) throw Error('VP8 WebM recording unsupported');
      const recorder = new MediaRecorder(stream, { mimeType: mime }), chunks = [];
      recorder.ondataavailable = event => chunks.push(event.data);
      const finished = new Promise(resolve => recorder.onstop = resolve);
      recorder.start(); let frame = 0;
      const timer = setInterval(() => { context.fillStyle = '#0c1a32'; context.fillRect(0,0,320,180);
        context.fillStyle = '#3cd4e8'; context.fillRect(20 + frame++ * 5 % 220,50,70,70);
        context.fillStyle = 'white'; context.font = '16px sans-serif'; context.fillText('YOGEN VIDEO TEST',25,30); },67);
      await new Promise(resolve => setTimeout(resolve,2100)); recorder.stop(); await finished; clearInterval(timer); stream.getTracks().forEach(track => track.stop());
      const bytes = new Uint8Array(await new Blob(chunks,{type:mime}).arrayBuffer());
      let text = ''; for(const byte of bytes) text += String.fromCharCode(byte);
      return btoa(text);
    });
    const bytes = Buffer.from(result, 'base64'); fs.writeFileSync(path.join(root,'assets/fixtures/phase05/فيديو-اختبار.webm'),bytes);
    console.log(JSON.stringify({webmBytes:bytes.length}));
  } finally { await browser.close(); }
})().catch(() => { console.error('WebM fixture preparation failed'); process.exitCode = 1; });
