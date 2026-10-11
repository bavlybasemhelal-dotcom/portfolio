/* Phase-02 page artwork: CSS volumes with six faces, planes and local materials. */
(() => {
  const faces='<i class="volume-front"></i><i class="volume-back"></i><i class="volume-left"></i><i class="volume-right"></i><i class="volume-top"></i><i class="volume-bottom"></i>';
  function markup(route,scale='public'){
    const kind=route==='work'||route.startsWith('project/')||route==='admin/projects'||route==='admin/media'?'gallery':route==='about'||route==='admin/team'||route==='admin/accounts'?'team':route==='contact'||route==='admin/company'?'message':route==='services'||route==='admin/storage'?'systems':route.startsWith('admin/editor')||route==='states'?'layers':'brand';
    const volume=`<div class="depth-volume">${faces}</div>`;
    return `<div class="depth-art depth-${scale} motif-${kind}" aria-hidden="true"><div class="depth-ground"></div><div class="depth-scene"><div class="depth-ring"></div>${volume}${volume}${volume}<div class="depth-plane"><i></i><i></i><i></i><span></span></div><div class="depth-plane plane-back"></div></div></div>`;
  }
  function mount(){
    const main=document.querySelector('#main');if(!main)return;
    const login=main.querySelector('#login-form');if(login)login.insertAdjacentHTML('afterbegin',markup('login','small'));
    main.querySelectorAll('.detail-visual').forEach(element=>element.classList.add('depth-detail-frame'));
    main.dataset.depth=main.querySelector('.depth-art,.sculpture-stage')?'true':'false';
  }
  window.YogenDepth={markup,mount};
})();
