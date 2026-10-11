/* Phase 02 visual model only. Native WebGL geometry, no services or dependencies. */
(() => {
  const root = document.documentElement;
  const systemMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const finePointer = matchMedia('(hover: hover) and (pointer: fine)');
  let disposeScene = () => {}, revealObserver, disposers = [], paused = false;
  let sourceVisual = null, activeAnimations = new Set();
  const reduced = () => root.dataset.reduced === 'true' || systemMotion.matches;
  function animate(element, frames, options) {
    if (!element || reduced()) return;
    const animation = element.animate(frames, options);
    activeAnimations.add(animation);
    animation.finished.catch(() => {}).finally(() => activeAnimations.delete(animation));
    return animation;
  }
  function listen(element, event, handler) {
    element.addEventListener(event, handler);
    disposers.push(() => element.removeEventListener(event, handler));
  }
  function destroy() {
    disposeScene(); disposeScene = () => {};
    revealObserver?.disconnect();
    disposers.forEach(dispose => dispose()); disposers = [];
    activeAnimations.forEach(animation => animation.cancel()); activeAnimations.clear();
    document.querySelectorAll('.visual-transition').forEach(element => element.remove());
  }
  function capture(element) {
    if (!element || reduced()) { sourceVisual = null; return; }
    const bounds = element.getBoundingClientRect();
    sourceVisual = { bounds, background: getComputedStyle(element).backgroundImage,
      position: getComputedStyle(element).backgroundPosition, size: getComputedStyle(element).backgroundSize };
  }
  function sharedVisual(target) {
    const source = sourceVisual; sourceVisual = null;
    if (!source || !target || reduced()) return;
    const bounds = target.getBoundingClientRect();
    if (source.bounds.width <= 0 || bounds.width <= 0) return;
    const clone = document.createElement('div');
    clone.className = 'visual-transition'; clone.setAttribute('aria-hidden', 'true');
    Object.assign(clone.style, { left: bounds.left+'px', top: bounds.top+'px', width: bounds.width+'px', height: bounds.height+'px',
      backgroundImage: source.background, backgroundPosition: source.position, backgroundSize: source.size });
    document.body.append(clone);
    const animation = animate(clone, [
      { transform: `translate(${source.bounds.left-bounds.left}px,${source.bounds.top-bounds.top}px) scale(${source.bounds.width/bounds.width},${source.bounds.height/bounds.height})`, opacity: 1, offset:0 },
      { transform: 'translate(0,0) scale(1,1)', opacity: 1, offset:.8 },
      { transform: 'translate(0,0) scale(1,1)', opacity: 0, offset:1 }
    ], { duration: 620, easing: 'cubic-bezier(.22,1,.36,1)', fill: 'both' });
    animation?.finished.catch(() => {}).finally(() => clone.remove());
  }
  function mount(options = {}) {
    const main = document.querySelector('#main');
    if (options.change === 'theme') {
      animate(document.body, [{opacity:.72},{opacity:1}], {duration:320,easing:'ease-out'});
    } else if (options.change === 'filter' || options.change === 'tab') {
      animate(main?.querySelector('.grid,.editor-form,.panel'), [{opacity:.5,transform:'translateY(12px)'},{opacity:1,transform:'none'}], {duration:320,easing:'ease-out'});
    } else if (options.change !== 'search') {
      animate(main, [{opacity:.55,transform:'translateY(18px)'},{opacity:1,transform:'none'}], {duration:460,easing:'cubic-bezier(.22,1,.36,1)'});
    }
    const candidates = main?.querySelectorAll('.hero-copy > *, .section-head, .project-card, .feature, .cta-band, .detail-copy > section') || [];
    revealObserver = new IntersectionObserver(entries => {
      const visible = entries.filter(entry => entry.isIntersecting);
      visible.forEach((entry,index) => {
        entry.target.dataset.revealed = 'true'; revealObserver.unobserve(entry.target);
        animate(entry.target, [{opacity:.15,transform:'translateY(30px)'},{opacity:1,transform:'none'}],
          {duration:720,delay:Math.min(index*65,195),easing:'cubic-bezier(.22,1,.36,1)'});
      });
    }, { threshold:.12, rootMargin:'0px 0px -25px 0px' });
    candidates.forEach(element => {
      if (reduced() || options.change === 'search' || options.change === 'filter') element.dataset.revealed = 'true';
      else revealObserver.observe(element);
    });
    // Cards remain ordinary links: keyboard/touch get the same actionable content.
    main?.querySelectorAll('.project-card').forEach(card => {
      listen(card, 'pointermove', event => {
        if (reduced() || !finePointer.matches) return;
        const rect = card.getBoundingClientRect();
        card.style.setProperty('--tilt-x', ((.5-(event.clientY-rect.top)/rect.height)*5)+'deg');
        card.style.setProperty('--tilt-y', (((event.clientX-rect.left)/rect.width-.5)*7)+'deg');
      });
      listen(card, 'pointerleave', () => { card.style.setProperty('--tilt-x','0deg');card.style.setProperty('--tilt-y','0deg'); });
    });
    const stage = document.querySelector('.sculpture-stage');
    if (stage) disposeScene = createScene(stage);
    sharedVisual(main?.querySelector('.detail-visual .thumb'));
  }
  function dialog(element, source) {
    animate(element, [{opacity:0,transform:'translateY(20px) scale(.96)'},{opacity:1,transform:'none'}], {duration:360,easing:'cubic-bezier(.22,1,.36,1)'});
    if (source) animate(element.querySelector('.thumb'),[{opacity:.65,transform:'scale(.94)'},{opacity:1,transform:'none'}],{duration:460,easing:'cubic-bezier(.22,1,.36,1)'});
  }
  function closeDialog(element) {
    if (!element?.open) return;
    // Native close restores focus immediately; the decorative transition never delays it.
    const rect = element.getBoundingClientRect();
    element.close();
    if (!reduced()) {
      const ghost = document.createElement('div'); ghost.className = 'dialog-exit'; ghost.setAttribute('aria-hidden','true');
      Object.assign(ghost.style,{left:rect.left+'px',top:rect.top+'px',width:rect.width+'px',height:rect.height+'px'});
      document.body.append(ghost);
      const animation=animate(ghost,[{opacity:.35,transform:'none'},{opacity:0,transform:'translateY(12px) scale(.97)'}],{duration:180,easing:'ease-in'});
      animation?.finished.catch(()=>{}).finally(()=>ghost.remove());
    }
  }
  function pause() {
    paused = !paused;
    document.querySelector('.sculpture-stage')?.dispatchEvent(new Event('motionstate'));
  }
  function createScene(stage) {
    const canvas = stage.querySelector('canvas');
    let gl;
    try { gl = canvas.getContext('webgl', {alpha:true,antialias:true,preserveDrawingBuffer:true}); } catch (_) {}
    if (!gl) { stage.dataset.renderer='fallback'; return () => {}; }
    const vertex = `attribute vec3 aPosition; attribute vec3 aNormal; attribute vec3 aColor;
      uniform mat4 uModel; uniform mat4 uProjection; varying vec3 vNormal; varying vec3 vColor; varying vec3 vPosition;
      void main(){vec4 world=uModel*vec4(aPosition,1.0);vPosition=world.xyz;vNormal=mat3(uModel)*aNormal;vColor=aColor;gl_Position=uProjection*world;}`;
    const fragment = `precision mediump float;varying vec3 vNormal;varying vec3 vColor;varying vec3 vPosition;
      void main(){vec3 n=normalize(vNormal);vec3 eye=normalize(-vPosition);vec3 key=normalize(vec3(-.7,1.1,1.4));
      float diffuse=max(dot(n,key),0.0);float fill=max(dot(n,normalize(vec3(1.0,-.15,.4))),0.0);
      float spec=pow(max(dot(n,normalize(key+eye)),0.0),70.0);float rim=pow(1.0-max(dot(n,eye),0.0),2.8);
      vec3 col=vColor*(.28+diffuse*.82+fill*.32)+vec3(.64,.86,1.0)*spec*.8+vec3(.06,.42,.85)*rim*.42;
      gl_FragColor=vec4(col,1.0);}`;
    const shaders = [];
    function compile(type,source){const shader=gl.createShader(type);shaders.push(shader);gl.shaderSource(shader,source);gl.compileShader(shader);if(!gl.getShaderParameter(shader,gl.COMPILE_STATUS))throw new Error(gl.getShaderInfoLog(shader));return shader;}
    const program=gl.createProgram();
    try { gl.attachShader(program,compile(gl.VERTEX_SHADER,vertex));gl.attachShader(program,compile(gl.FRAGMENT_SHADER,fragment));gl.linkProgram(program);if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw new Error('Scene link failed'); }
    catch (_) { shaders.forEach(shader=>gl.deleteShader(shader));gl.deleteProgram(program);stage.dataset.renderer='fallback';return()=>{}; }
    const positions=[],normals=[],colors=[];
    const normalize = v => {const length=Math.hypot(...v)||1;return v.map(n=>n/length);};
    function triangle(a,b,c,color){
      const u=b.map((value,index)=>value-a[index]),v=c.map((value,index)=>value-a[index]);
      const n=normalize([u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]);
      [a,b,c].forEach(point=>{positions.push(...point);normals.push(...n);colors.push(...color);});
    }
    function triangulate(poly){
      const area=poly.reduce((sum,p,i)=>{const q=poly[(i+1)%poly.length];return sum+p[0]*q[1]-q[0]*p[1];},0);
      const ids=poly.map((_,i)=>i);if(area<0)ids.reverse();const result=[];
      const cross=(a,b,c)=>(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]);
      for(let guard=0;ids.length>3&&guard<100;guard++){
        let found=false;
        for(let i=0;i<ids.length;i++){
          const a=ids[(i+ids.length-1)%ids.length],b=ids[i],c=ids[(i+1)%ids.length];
          if(cross(poly[a],poly[b],poly[c])<=.00001)continue;
          const inside=ids.some(id=>id!==a&&id!==b&&id!==c&&cross(poly[a],poly[b],poly[id])>=0&&cross(poly[b],poly[c],poly[id])>=0&&cross(poly[c],poly[a],poly[id])>=0);
          if(!inside){result.push([a,b,c]);ids.splice(i,1);found=true;break;}
        }
        if(!found)break;
      }
      if(ids.length===3)result.push([...ids]);return result;
    }
    function extrude(poly,depth,z,color){
      const area=poly.reduce((sum,p,i)=>{const q=poly[(i+1)%poly.length];return sum+p[0]*q[1]-q[0]*p[1];},0);if(area<0)poly=[...poly].reverse();
      const center=poly.reduce((sum,p)=>[sum[0]+p[0]/poly.length,sum[1]+p[1]/poly.length],[0,0]);
      const inner=poly.map(p=>p.map((value,i)=>center[i]+(value-center[i])*.967));
      const layers=[inner.map(p=>[...p,z-depth/2]),poly.map(p=>[...p,z-depth/2+.04]),poly.map(p=>[...p,z+depth/2-.04]),inner.map(p=>[...p,z+depth/2])];
      triangulate(inner).forEach(([a,b,c])=>{triangle(layers[3][a],layers[3][b],layers[3][c],color);triangle(layers[0][c],layers[0][b],layers[0][a],color.map(n=>n*.72));});
      for(let layer=0;layer<3;layer++)for(let i=0;i<poly.length;i++){const next=(i+1)%poly.length;const shade=layer===1?.70:1.10;const col=color.map(n=>n*shade);triangle(layers[layer][i],layers[layer][next],layers[layer+1][next],col);triangle(layers[layer][i],layers[layer+1][next],layers[layer+1][i],col);}
    }
    // Folded, bevelled prisms inspired by YOGEN's ribbon silhouette. Original logo stays unchanged in the header.
    extrude([[-1.27,1.05],[-1.27,1.76],[-.10,.91],[-.52,.49]],.26,.09,[.025,.63,.95]);
    extrude([[-.52,-.72],[-.52,.35],[-.37,.78],[1.28,1.77],[1.28,1.05],[.21,.43],[.02,.20],[.02,-1.11]],.38,0,[.025,.35,.89]);
    extrude([[-.52,-.73],[.02,-1.11],[1.23,-.43],[1.23,.28],[.87,.48],[.35,.21],[.35,.045],[.78,-.13],[.78,-.28],[.13,-.66],[.13,-.12],[-.52,-.42]],.36,.22,[.025,.23,.66]);
    // A separate orbit gives the composition spatial depth without covering the copy.
    for(let i=0;i<100;i++){
      const a=i/100*Math.PI*2,b=(i+1)/100*Math.PI*2;
      const point=(angle,radius)=>[Math.cos(angle)*radius,Math.sin(angle)*radius*.39-.2,Math.sin(angle)*radius*.60-.45];
      const color=[.035,.38,.70];triangle(point(a,1.92),point(b,1.92),point(b,1.934),color);triangle(point(a,1.92),point(b,1.934),point(a,1.934),color);
    }
    const buffers=[];
    gl.useProgram(program);
    function attribute(name,data){const buffer=gl.createBuffer();buffers.push(buffer);gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(data),gl.STATIC_DRAW);const index=gl.getAttribLocation(program,name);gl.enableVertexAttribArray(index);gl.vertexAttribPointer(index,3,gl.FLOAT,false,0,0);}
    attribute('aPosition',positions);attribute('aNormal',normals);attribute('aColor',colors);
    const modelLocation=gl.getUniformLocation(program,'uModel'),projectionLocation=gl.getUniformLocation(program,'uProjection');
    gl.enable(gl.DEPTH_TEST);gl.clearColor(0,0,0,0);
    let frame=0,visible=true,disposed=false,lost=false,last=0,elapsed=0;
    let pointer=[0,0],currentPointer=[0,0];
    const mobile=matchMedia('(max-width:600px)');
    function multiply(a,b){const out=new Float32Array(16);for(let col=0;col<4;col++)for(let row=0;row<4;row++)for(let k=0;k<4;k++)out[col*4+row]+=a[k*4+row]*b[col*4+k];return out;}
    function draw(now){
      if(disposed||lost)return;
      const running=visible&&!document.hidden&&!paused&&!reduced();
      if(running&&last)elapsed+=Math.min(now-last,40);last=now;
      currentPointer=currentPointer.map((v,i)=>reduced()||paused?0:v+(pointer[i]-v)*.07);
      const width=Math.max(1,Math.round(canvas.clientWidth*Math.min(devicePixelRatio,mobile.matches?1.3:1.7))),height=Math.max(1,Math.round(canvas.clientHeight*Math.min(devicePixelRatio,mobile.matches?1.3:1.7)));
      if(canvas.width!==width||canvas.height!==height){canvas.width=width;canvas.height=height;}
      gl.viewport(0,0,width,height);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);
      const time=elapsed/1000;
      const x=-.12+(reduced()?0:Math.sin(time*.65)*.075+currentPointer[1]*.14),y=-.36+(reduced()?0:Math.sin(time*.5)*.24+currentPointer[0]*.24);
      const cx=Math.cos(x),sx=Math.sin(x),cy=Math.cos(y),sy=Math.sin(y);
      const rotateX=new Float32Array([1,0,0,0,0,cx,sx,0,0,-sx,cx,0,0,0,0,1]);
      const rotateY=new Float32Array([cy,0,-sy,0,0,1,0,0,sy,0,cy,0,0,0,0,1]);
      const model=multiply(rotateY,rotateX);model[13]=-.24+(reduced()?0:Math.sin(time*.8)*.07);model[14]=-5.35;
      const f=1/Math.tan(.70/2),near=.1,far=30,aspect=width/height;
      const projection=new Float32Array([f/aspect,0,0,0,0,f,0,0,0,0,(far+near)/(near-far),-1,0,0,2*far*near/(near-far),0]);
      gl.uniformMatrix4fv(modelLocation,false,model);gl.uniformMatrix4fv(projectionLocation,false,projection);gl.drawArrays(gl.TRIANGLES,0,positions.length/3);
      canvas.dataset.frame=String(Number(canvas.dataset.frame||0)+1);stage.dataset.running=String(running);stage.dataset.angle=y.toFixed(4);
      if(running)frame=requestAnimationFrame(draw);else frame=0;
    }
    function sync(){cancelAnimationFrame(frame);last=0;frame=0;if(!disposed)draw(performance.now());updateControl();}
    function updateControl(){const control=stage.querySelector('[data-action="pause-scene"]');if(!control)return;const ar=root.lang==='ar';control.disabled=reduced();control.setAttribute('aria-pressed',String(paused));control.textContent=reduced()?(ar?'الحركة مخففة':'Reduced motion'):paused?(ar?'تشغيل الحركة':'Play motion'):(ar?'إيقاف الحركة':'Pause motion');}
    const observer=new IntersectionObserver(entries=>{visible=entries[0].isIntersecting;sync();},{threshold:.06});observer.observe(stage);
    const resize=new ResizeObserver(()=>{if(!frame)sync();});resize.observe(stage);
    const onPointer=event=>{if(!finePointer.matches||reduced()||paused)return;const rect=stage.getBoundingClientRect();pointer=[(event.clientX-rect.left)/rect.width-.5,(event.clientY-rect.top)/rect.height-.5];};
    const onLeave=()=>{pointer=[0,0];};
    const onLost=event=>{event.preventDefault();lost=true;cancelAnimationFrame(frame);stage.dataset.renderer='fallback';};
    const onRestored=()=>{window.dispatchEvent(new Event('yogenmotionchange'));};
    stage.addEventListener('pointermove',onPointer);stage.addEventListener('pointerleave',onLeave);stage.addEventListener('motionstate',sync);
    canvas.addEventListener('webglcontextlost',onLost);canvas.addEventListener('webglcontextrestored',onRestored);
    document.addEventListener('visibilitychange',sync);systemMotion.addEventListener('change',sync);
    stage.dataset.renderer='webgl';stage.dataset.triangles=String(positions.length/9);sync();
    return()=>{disposed=true;cancelAnimationFrame(frame);observer.disconnect();resize.disconnect();stage.removeEventListener('pointermove',onPointer);stage.removeEventListener('pointerleave',onLeave);stage.removeEventListener('motionstate',sync);canvas.removeEventListener('webglcontextlost',onLost);canvas.removeEventListener('webglcontextrestored',onRestored);document.removeEventListener('visibilitychange',sync);systemMotion.removeEventListener('change',sync);buffers.forEach(buffer=>gl.deleteBuffer(buffer));shaders.forEach(shader=>gl.deleteShader(shader));gl.deleteProgram(program);gl.getExtension('WEBGL_lose_context')?.loseContext();};
  }
  systemMotion.addEventListener('change',()=>window.dispatchEvent(new Event('yogenmotionchange')));
  window.YogenMotion={mount,destroy,capture,dialog,closeDialog,pause,reduced,animate};
})();
