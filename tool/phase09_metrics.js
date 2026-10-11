// Local QA only: exposed DOM metadata contains timings, never application data.
(() => {
  const node = document.createElement('meta');
  node.name = 'yogen-qa-metrics';
  document.head.appendChild(node);
  const run = new URL(location.href).searchParams.get('run') || 'qa';
  const loadKey = 'yogen-qa-load-'+run;
  const pageLoads = Number(sessionStorage.getItem(loadKey) || 0) + 1;
  sessionStorage.setItem(loadKey, String(pageLoads));
  const result = { pageLoads, browser: navigator.userAgent, viewport: [innerWidth, innerHeight],
    firstFlutterFrameMs: null, shellPaintedMs: null, languageResponseMs: [], resources: [],
    visibility: [], browserRafCadence: null };
  function publish() {
    result.resources = performance.getEntriesByType('resource').map(v => ({
      name: new URL(v.name).origin === location.origin ? new URL(v.name).pathname : 'external',
      durationMs: v.duration, transferBytes: v.transferSize, encodedBytes: v.encodedBodySize,
      decodedBytes: v.decodedBodySize,
    }));
    result.localTransferredBytes = result.resources.reduce((v, e) => v + (e.name !== 'external' ? e.transferBytes : 0),
      performance.getEntriesByType('navigation')[0]?.transferSize || 0);
    node.content = JSON.stringify(result);
  }
  let action = null, language = document.documentElement.lang;
  function start(event) {
    const target = event.target.closest?.('[role="button"],button');
    const label = target?.getAttribute('aria-label') || target?.textContent || '';
    if (/^(English|العربية)$/.test(label.trim())) action = performance.now();
  }
  // Flutter's engine handles input at window level; observe before its handler.
  window.addEventListener('pointerdown', start, true);
  window.addEventListener('click', start, true);
  window.addEventListener('keydown', event => {
    if (event.key === 'Enter' || event.key === ' ') action = performance.now();
  }, true);
  new MutationObserver(() => {
    const next = document.documentElement.lang;
    if (next !== language && action !== null) {
      const started = action; action = null;
      requestAnimationFrame(() => requestAnimationFrame(() => {
        result.languageResponseMs.push(performance.now() - started); publish();
      }));
    }
    language = next;
  }).observe(document.documentElement, { attributes: true, attributeFilter: ['lang'] });
  new PerformanceObserver(publish).observe({ type: 'resource', buffered: true });
  document.addEventListener('visibilitychange', () => { result.visibility.push(document.visibilityState); publish(); });
  window.addEventListener('flutter-first-frame', () => {
    result.firstFlutterFrameMs = performance.now();
    requestAnimationFrame(() => requestAnimationFrame(() => { result.shellPaintedMs = performance.now(); publish(); }));
    const samples = []; let previous = null, started = null;
    function sample(time) {
      started ??= time;
      if (previous !== null) samples.push(time - previous);
      previous = time;
      if (time - started < 5000) requestAnimationFrame(sample);
      else {
        const sorted = samples.toSorted((a,b) => a-b);
        result.browserRafCadence = { samples: sorted.length, medianMs: sorted[Math.floor(sorted.length*.5)],
          p95Ms: sorted[Math.floor(sorted.length*.95)], over34ms: sorted.filter(v=>v>34).length };
        publish();
      }
    }
    requestAnimationFrame(sample);
  });
  publish();
})();
