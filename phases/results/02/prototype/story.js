/* Phase 02 scroll-v4: native scroll chapters and a 3D project exhibition. */
(() => {
  let active=0, cleanup=()=>{}, options;
  const root=document.documentElement;
  const reduced=()=>window.YogenMotion?.reduced();
  const label=(ar,en)=>options.lang==='ar'?ar:en;
  function markup(input){
    options=input;active=Math.min(active,input.projects.length-1);
    const p=input.projects[active],title=input.name(p);
    return `<div class="project-scroll-track" data-scroll-mode="pending" style="height:${700+(input.projects.length-1)*240}px"><div class="showcase" aria-label="${label('عرض المشاريع التفاعلي','Interactive project exhibition')}">
      <div class="scroll-gallery-guide"><span>${input.icon('arrow','scroll-arrow')}<span data-scroll-hint>${label('مرّر لأسفل لعرض المشروع التالي','Scroll down for the next project')}</span></span><button data-showcase-exit>${label('تخطّي المعرض','Skip exhibition')}</button></div>
      <div class="showcase-layout"><div class="showcase-copy">
        <div class="showcase-category">${input.groupName(p.group)}</div><h3 id="showcase-title">${input.esc(title)}</h3>
        <p class="muted showcase-summary">${label('كل عمل له مساحة لعرض تجربته. اللقطة والعنوان من مرجع أعمالنا؛ التفاصيل الموثقة يضيفها الفريق لاحقًا.','Every project has room to tell its story. This title and screenshot come from our work reference; the team will add verified details.')}</p>
        <a class="btn primary showcase-open" href="#project/${p.id}" data-project="${p.id}">${label('استكشف المشروع','Explore this project')}${input.icon('arrow','arrow')}</a>
        <div class="showcase-controls"><button class="icon-btn gallery-prev" data-showcase-step="-1" aria-label="${label('المشروع السابق','Previous project')}">${input.icon('arrow','arrow')}</button><output class="showcase-count latin" aria-live="polite" aria-atomic="true">${String(active+1).padStart(2,'0')} / ${input.projects.length}</output><button class="icon-btn" data-showcase-step="1" aria-label="${label('المشروع التالي','Next project')}">${input.icon('arrow','arrow')}</button></div>
      </div><div class="project-theatre" data-active="${p.id}">${layers()}</div></div>
      <div class="exhibition-index"><span class="small muted">${label('كل الأعمال، في نفس المساحة.','Every project. One exhibition.')}</span><div class="gallery-index" aria-label="${label('اختيار مشروع من جميع الأعمال','Choose from all projects')}">${input.projects.map((item,index)=>`<button data-showcase-index="${index}" aria-pressed="${index===active}" aria-label="${input.esc(input.name(item))}" title="${input.esc(input.name(item))}">${String(index+1).padStart(2,'0')}</button>`).join('')}</div><select class="scroll-project-select" aria-label="${label('اختيار مشروع','Choose a project')}">${input.projects.map((item,index)=>`<option value="${index}" ${index===active?'selected':''}>${String(index+1).padStart(2,'0')} — ${input.esc(input.name(item))}</option>`).join('')}</select></div>
    </div></div>`;
  }
  function layers(){
    const list=options.projects,p=list[active],near=list[(active+1)%list.length],far=list[(active+2)%list.length];
    return `<div class="theatre-orbit" aria-hidden="true"></div><div class="theatre-plinth" aria-hidden="true"></div>
      <div class="showcase-layer layer-far" aria-hidden="true"><div class="browser-bar"><i></i><i></i><i></i></div>${options.thumb(far,false)}</div>
      <div class="showcase-layer layer-near" aria-hidden="true"><div class="browser-bar"><i></i><i></i><i></i></div>${options.thumb(near,false)}</div>
      <a class="showcase-layer showcase-front" href="#project/${p.id}" data-project="${p.id}" aria-label="${options.esc(label('فتح المشروع: ','Open project: ')+options.name(p))}"><div class="browser-bar"><div><i></i><i></i><i></i></div><span class="latin">YOGEN / ${p.id}</span></div>${options.thumb(p,false)}<div class="frame-caption"><span>${options.esc(options.name(p))}</span>${options.icon('arrow','arrow')}</div></a>`;
  }
  function select(index){
    const gallery=document.querySelector('.showcase');if(!gallery)return;
    const next=(index+options.projects.length)%options.projects.length;if(next===active)return;
    const focusedFrame=gallery.querySelector('.showcase-front')===document.activeElement;
    active=next;
    const p=options.projects[active],stage=gallery.querySelector('.project-theatre');
    stage.innerHTML=layers();stage.dataset.active=p.id;
    gallery.querySelector('#showcase-title').textContent=options.name(p);
    gallery.querySelector('.showcase-category').textContent=options.groupName(p.group);
    const link=gallery.querySelector('.showcase-open');link.href='#project/'+p.id;link.dataset.project=p.id;
    gallery.querySelector('.showcase-count').textContent=String(active+1).padStart(2,'0')+' / '+options.projects.length;
    gallery.querySelectorAll('[data-showcase-index]').forEach(button=>button.setAttribute('aria-pressed',String(+button.dataset.showcaseIndex===active)));
    gallery.querySelector('.scroll-project-select').value=String(active);
    gallery.querySelector('[data-scroll-hint]').textContent=active===options.projects.length-1?label('آخر مشروع — كمّل التمرير لباقي الصفحة','Last project — keep scrolling to continue'):label('مرّر لأسفل لعرض المشروع التالي','Scroll down for the next project');
    if(focusedFrame)stage.querySelector('.showcase-front').focus({preventScroll:true});
    window.YogenMotion?.animate(stage.querySelector('.showcase-front'),[{opacity:.35,transform:'translateY(26px) rotateX(13deg) rotateY(-18deg)'},{opacity:1,transform:'translateY(0) rotateX(6deg) rotateY(-10deg)'}],{duration:620,easing:'cubic-bezier(.22,1,.36,1)'});
    window.YogenMotion?.animate(gallery.querySelector('.showcase-copy h3'),[{opacity:.4,transform:'translateY(8px)'},{opacity:1,transform:'none'}],{duration:300,easing:'ease-out'});
  }
  function position(){const track=document.querySelector('.project-scroll-track');return track?.dataset.scrollMode==='pinned'&&scrollY>=+track.dataset.start-2&&scrollY<=+track.dataset.end+2?{index:active}:null;}
  function mount(input={}){
    const chapter=document.querySelector('.identity-chapter'),gallery=document.querySelector('.showcase');
    const track=gallery?.closest('.project-scroll-track');
    let raf=0,disposed=false,enabled=false,step=240,start=0,range=0;
    const layout=(restore=false)=>{
      if(!track)return;
      const wasEnabled=enabled,previousStart=start,previousRange=range;
      const header=document.querySelector('header').getBoundingClientRect().height,top=header+12;
      track.style.setProperty('--project-top',top+'px');
      track.style.setProperty('--project-budget',Math.max(0,innerHeight-top-12)+'px');
      track.dataset.scrollMode='measure';
      track.dataset.density='comfortable';
      let height=gallery.getBoundingClientRect().height;
      if(!reduced()&&height+top+12>innerHeight){
        track.dataset.density='compact';
        height=gallery.getBoundingClientRect().height;
      }
      enabled=!reduced()&&height+top+12<=innerHeight;
      track.dataset.scrollMode=enabled?'pinned':'flow';
      track.style.height=enabled?height+step*(options.projects.length-1)+'px':'auto';
      let documentTop=0;for(let node=track;node;node=node.offsetParent)documentTop+=node.offsetTop;
      start=documentTop-top;range=step*(options.projects.length-1);
      track.dataset.start=start.toFixed(2);track.dataset.step=String(step);track.dataset.end=(start+range).toFixed(2);
      if(enabled&&restore&&((wasEnabled&&scrollY>=previousStart-2&&scrollY<=previousStart+previousRange+2)||(!wasEnabled&&scrollY>=start&&scrollY<=start+range))){window.scrollTo({top:start+active*step,behavior:'instant'});}
      const hint=gallery.querySelector('[data-scroll-hint]');hint.textContent=enabled?(active===options.projects.length-1?label('آخر مشروع — كمّل التمرير لباقي الصفحة','Last project — keep scrolling to continue'):label('مرّر لأسفل لعرض المشروع التالي','Scroll down for the next project')):label('اختَر مشروعًا بالسابق والتالي أو الفهرس','Choose a project with the controls or index');
    };
    const goTo=index=>{
      const next=(index+options.projects.length)%options.projects.length;select(next);layout(false);
      if(enabled)window.scrollTo({top:start+next*step,behavior:'instant'});
    };
    const update=()=>{
      raf=0;if(disposed)return;
      if(chapter){
        const bounds=chapter.getBoundingClientRect(),header=document.querySelector('header').getBoundingClientRect().height;
        chapter.style.setProperty('--sticky-top',header+'px');
        const progress=reduced()?0:Math.max(0,Math.min(1,(header-bounds.top)/Math.max(1,bounds.height-innerHeight+header)));
        chapter.style.setProperty('--chapter-progress',progress.toFixed(4));chapter.dataset.progress=progress.toFixed(4);
        const stage=chapter.querySelector('.sculpture-stage');if(stage){stage.dataset.scroll=progress.toFixed(4);stage.dispatchEvent(new Event('scrollscene'));}
      }
      if(gallery){const bounds=gallery.getBoundingClientRect();const entrance=reduced()?1:Math.max(0,Math.min(1,(innerHeight-bounds.top)/(innerHeight*.70)));gallery.style.setProperty('--exhibition-entry',entrance.toFixed(4));gallery.dataset.entry=entrance.toFixed(4);}
      if(enabled&&scrollY>=start-2){const next=Math.max(0,Math.min(options.projects.length-1,Math.floor((scrollY-start+2)/step)));if(next!==active){select(next);layout(false);}}
    };
    const schedule=()=>{if(!disposed&&!raf)raf=requestAnimationFrame(update);};
    const click=event=>{const control=event.target.closest('[data-showcase-step]'),index=event.target.closest('[data-showcase-index]');if(event.target.closest('[data-showcase-exit]')){const next=document.querySelector('.process-chapter');if(next){window.scrollTo({top:next.getBoundingClientRect().top+scrollY-document.querySelector('header').getBoundingClientRect().height-16,behavior:reduced()?'instant':'smooth'});const heading=next.querySelector('h2');heading?.setAttribute('tabindex','-1');heading?.focus({preventScroll:true});}}else if(control)goTo(active+Number(control.dataset.showcaseStep));else if(index)goTo(Number(index.dataset.showcaseIndex));};
    const change=event=>{if(event.target.matches('.scroll-project-select'))goTo(Number(event.target.value));};
    const focusSelection=()=>{const select=gallery.querySelector('.scroll-project-select');if(getComputedStyle(select).display!=='none')select.focus({preventScroll:true});else gallery.querySelector(`[data-showcase-index="${active}"]`)?.focus({preventScroll:true});};
    const key=event=>{if(!event.target.closest('.gallery-index,.showcase-controls'))return;const forward=options.lang==='ar'?'ArrowLeft':'ArrowRight',backward=options.lang==='ar'?'ArrowRight':'ArrowLeft';if(event.key===forward||event.key===backward){event.preventDefault();goTo(active+(event.key===forward?1:-1));focusSelection();}else if(event.key==='Home'||event.key==='End'){event.preventDefault();goTo(event.key==='Home'?0:options.projects.length-1);focusSelection();}};
    const pointer=event=>{if(reduced()||!matchMedia('(hover:hover) and (pointer:fine)').matches)return;const stage=event.target.closest('.project-theatre');if(!stage)return;const rect=stage.getBoundingClientRect();stage.style.setProperty('--frame-x',((event.clientY-rect.top)/rect.height-.5)*-5+'deg');stage.style.setProperty('--frame-y',((event.clientX-rect.left)/rect.width-.5)*7+'deg');};
    const leave=()=>{const stage=gallery?.querySelector('.project-theatre');stage?.style.setProperty('--frame-x','0deg');stage?.style.setProperty('--frame-y','0deg');};
    if(gallery){gallery.addEventListener('click',click);gallery.addEventListener('change',change);gallery.addEventListener('keydown',key);gallery.addEventListener('pointermove',pointer);gallery.addEventListener('pointerleave',leave);}
    const visibility=()=>{root.dataset.pageHidden=String(document.hidden);};
    document.addEventListener('visibilitychange',visibility);visibility();
    const resize=()=>{layout(true);schedule();};
    const headerObserver=new ResizeObserver(()=>{if(!disposed)resize();});headerObserver.observe(document.querySelector('header'));
    window.addEventListener('scroll',schedule,{passive:true});window.addEventListener('resize',resize);layout(true);
    if(enabled&&input.position){select(input.position.index);window.scrollTo({top:start+active*step,behavior:'instant'});}
    schedule();
    document.fonts.ready.then(()=>{if(!disposed){layout(true);schedule();}});
    cleanup=()=>{disposed=true;cancelAnimationFrame(raf);headerObserver.disconnect();window.removeEventListener('scroll',schedule);window.removeEventListener('resize',resize);document.removeEventListener('visibilitychange',visibility);if(gallery){gallery.removeEventListener('click',click);gallery.removeEventListener('change',change);gallery.removeEventListener('keydown',key);gallery.removeEventListener('pointermove',pointer);gallery.removeEventListener('pointerleave',leave);}};
  }
  window.YogenStory={markup,mount,position,destroy:()=>cleanup()};
})();
