(() => {
  const INSTALL_URL='./downloads/Install_Edge_Connector.cmd?v=20261015-2';
  const UNINSTALL_URL='./downloads/Uninstall_Edge_Connector.cmd?v=20261015-1';
  const VERSION_URL='./downloads/version.json';
  const PROTOCOL='edge-connector://run';
  const STATE_KEY='edgeConnectorState';
  const VERSION_KEY='edgeConnectorInstalledVersion';
  const INSTALL_NOTICE='edgeConnectorInstallerDownloaded';
  const DELETE_NOTICE='edgeConnectorUninstallerDownloaded';
  let channel=null,versionUi={status:'idle',repo:'',installed:'',msg:''};

  const T={
    ko:{
      installed:'설치됨',notInstalled:'미설치',pending:'삭제 완료 대기 중',
      install:'↓ Edge Connector 설치',run:'▶ Edge Connector 실행',version:'↻ 최신 버전 확인',latest:'✓ 최신 버전',reinstall:'↻ 최신 버전 재설치',del:'🗑 설치 삭제',
      installDownloaded:'⚠ 다운로드 완료 · 설치 파일을 1회 실행하세요',deleteDownloaded:'⚠ 삭제 파일 다운로드됨 · 1회 실행하세요',
      descInstalled:'Edge Connector가 설치되어 있습니다.',descNot:'처음 사용하는 PC에서는 설치 파일을 다운로드한 뒤 한 번 실행해야 합니다.',
      noteInstalled:'버전 확인, 실행, 삭제를 이 화면에서 관리할 수 있습니다.',noteNot:'다운로드만으로는 설치되지 않습니다. 최초 한 번 CMD 실행이 필요합니다.',
      installTitle:'중요 · 다운로드만으로 설치되지 않습니다',installLead:'다운로드된 설치 CMD를 한 번 실행하세요.',
      is1:'브라우저 다운로드 목록을 엽니다.',is2:'Install_Edge_Connector.cmd를 실행합니다.',is3:'설치 완료 후 이 페이지가 자동으로 다시 열립니다.',
      deleteTitle:'삭제 파일을 한 번 실행하세요',deleteLead:'다운로드된 삭제 CMD를 실행하면 로컬 Edge Connector가 제거됩니다.',
      ds1:'브라우저 다운로드 목록에서 삭제 CMD를 찾습니다.',ds2:'Uninstall_Edge_Connector.cmd를 실행합니다.',ds3:'삭제 완료 후 이 페이지가 자동으로 다시 열립니다.',
      installedVer:'설치 버전',repoVer:'Repo 최신 버전',ok:'현재 설치된 Edge Connector가 최신 버전입니다.',old:'새 버전이 있습니다. 최신 버전 재설치를 권장합니다.',unknown:'설치 버전 정보가 없습니다. 최신 버전 재설치를 권장합니다.',repoFail:'Repo 버전 정보를 확인하지 못했습니다.'
    },
    en:{
      installed:'Installed',notInstalled:'Not installed',pending:'Waiting for uninstall',
      install:'↓ Install Edge Connector',run:'▶ Run Edge Connector',version:'↻ Check latest version',latest:'✓ Up to date',reinstall:'↻ Reinstall latest',del:'🗑 Uninstall',
      installDownloaded:'⚠ Download complete · Run the installer once',deleteDownloaded:'⚠ Uninstaller downloaded · Run it once',
      descInstalled:'Edge Connector is installed.',descNot:'On a new PC, download and run the installer once.',
      noteInstalled:'Manage version checks, launch and removal from this page.',noteNot:'Downloading alone does not install it. Run the CMD once.',
      installTitle:'Important · Downloading alone does not install it',installLead:'Run the downloaded installer CMD once.',
      is1:'Open your browser Downloads.',is2:'Run Install_Edge_Connector.cmd.',is3:'This page reopens automatically when installation finishes.',
      deleteTitle:'Run the uninstaller once',deleteLead:'Run the downloaded CMD to remove the local Edge Connector.',
      ds1:'Find the uninstaller CMD in Downloads.',ds2:'Run Uninstall_Edge_Connector.cmd.',ds3:'This page reopens automatically when removal finishes.',
      installedVer:'Installed version',repoVer:'Latest repo version',ok:'The installed Edge Connector is up to date.',old:'A newer version is available. Reinstalling the latest version is recommended.',unknown:'Installed version is unknown. Reinstalling the latest version is recommended.',repoFail:'Could not read the repo version.'
    }
  };

  const $=id=>document.getElementById(id);
  const lang=()=>localStorage.getItem('edgeConnectorLanguage')==='en'?'en':'ko';
  const tx=()=>T[lang()];
  const norm=v=>{const m=String(v||'').replace(/^v/i,'').match(/(\d+(?:\.\d+){1,3})/);return m?m[1]:''};
  const cmp=(a,b)=>{const x=norm(a).split('.').map(Number),y=norm(b).split('.').map(Number);for(let i=0;i<Math.max(x.length,y.length);i++){if((x[i]||0)>(y[i]||0))return 1;if((x[i]||0)<(y[i]||0))return-1}return 0};

  function publish(state){
    const p={state,ts:Date.now()};
    localStorage.setItem(STATE_KEY,JSON.stringify(p));
    try{channel?.postMessage(p)}catch(_){}
  }
  function state(){
    try{const p=JSON.parse(localStorage.getItem(STATE_KEY)||'null');if(p?.state)return p.state}catch(_){}
    return 'uninstalled';
  }
  function installed(){return state()==='installed'}

  function callback(){
    const u=new URL(location.href),s=u.searchParams.get('connector');
    if(s==='installed'){
      publish('installed');
      const v=norm(u.searchParams.get('version')||'');
      if(v)localStorage.setItem(VERSION_KEY,v);
      sessionStorage.removeItem(INSTALL_NOTICE);sessionStorage.removeItem(DELETE_NOTICE);
      u.searchParams.delete('connector');u.searchParams.delete('version');u.searchParams.delete('_');history.replaceState(null,'',u);
    }else if(s==='uninstalled'){
      publish('uninstalled');localStorage.removeItem(VERSION_KEY);
      sessionStorage.removeItem(INSTALL_NOTICE);sessionStorage.removeItem(DELETE_NOTICE);
      u.searchParams.delete('connector');u.searchParams.delete('_');history.replaceState(null,'',u);
    }
  }
  function download(url,name){const a=document.createElement('a');a.href=url;a.download=name;a.style.display='none';document.body.appendChild(a);a.click();setTimeout(()=>a.remove(),500)}
  async function repoVersion(){
    const r=await fetch(VERSION_URL+'?_='+Date.now(),{cache:'no-store'});if(!r.ok)throw 0;
    const j=await r.json();return norm(j.edgeConnectorVersion||j.version||j.latestVersion||'');
  }
  function paintText(){
    const l=lang(),t=tx();
    document.documentElement.lang=l;
    document.querySelectorAll('[data-k]').forEach(n=>n.textContent=l==='en'?n.dataset.e:n.dataset.k);
    document.querySelectorAll('[data-lang]').forEach(b=>b.classList.toggle('active',b.dataset.lang===l));
    $('installTitle').textContent=t.installTitle;$('installLead').textContent=t.installLead;
    $('is1').textContent=t.is1;$('is2').textContent=t.is2;$('is3').textContent=t.is3;
    $('deleteTitle').textContent=t.deleteTitle;$('deleteLead').textContent=t.deleteLead;
    $('ds1').textContent=t.ds1;$('ds2').textContent=t.ds2;$('ds3').textContent=t.ds3;
  }
  function render(){
    callback();paintText();const t=tx(),ok=installed(),deleting=sessionStorage.getItem(DELETE_NOTICE)==='1'&&ok;
    $('status').className='status '+(deleting?'pending':ok?'on':'');$('status').textContent='● '+(deleting?t.pending:ok?t.installed:t.notInstalled);
    $('desc').textContent=ok?t.descInstalled:t.descNot;$('note').textContent=ok?t.noteInstalled:t.noteNot;
    $('mainBtn').textContent=ok?t.run:(sessionStorage.getItem(INSTALL_NOTICE)==='1'?t.installDownloaded:t.install);
    $('mainBtn').className='btn '+(ok?'primary':sessionStorage.getItem(INSTALL_NOTICE)==='1'?'warn':'primary');
    $('versionBtn').style.display=ok?'':'none';$('deleteBtn').style.display=ok?'':'none';
    $('versionBtn').textContent=versionUi.status==='latest'?t.latest:(versionUi.status==='old'||versionUi.status==='unknown'?t.reinstall:t.version);
    $('deleteBtn').textContent=sessionStorage.getItem(DELETE_NOTICE)==='1'?t.deleteDownloaded:t.del;
    $('installNotice').classList.toggle('show',!ok&&sessionStorage.getItem(INSTALL_NOTICE)==='1');
    $('deleteNotice').classList.toggle('show',ok&&sessionStorage.getItem(DELETE_NOTICE)==='1');
    if(!ok){$('versionBox').className='versionBox';$('versionBox').innerHTML=''}
  }

  $('mainBtn').onclick=()=>{if(installed())location.href=PROTOCOL;else{download(INSTALL_URL,'Install_Edge_Connector.cmd');sessionStorage.setItem(INSTALL_NOTICE,'1');render()}};
  $('deleteBtn').onclick=()=>{if(!confirm(lang()==='en'?'Remove Edge Connector?':'설치된 Edge Connector를 삭제하시겠습니까?'))return;download(UNINSTALL_URL,'Uninstall_Edge_Connector.cmd');sessionStorage.setItem(DELETE_NOTICE,'1');render()};
  $('versionBtn').onclick=async()=>{
    const t=tx();
    if(versionUi.status==='old'||versionUi.status==='unknown'){download(INSTALL_URL,'Install_Edge_Connector.cmd');sessionStorage.setItem(INSTALL_NOTICE,'1');return render()}
    $('versionBtn').disabled=true;$('versionBtn').textContent=lang()==='en'?'Checking…':'버전 확인 중…';
    try{
      const rv=await repoVersion(),iv=norm(localStorage.getItem(VERSION_KEY)||'');versionUi.repo=rv;versionUi.installed=iv;
      if(!iv){versionUi.status='unknown';versionUi.msg=t.unknown}else if(cmp(iv,rv)>=0){versionUi.status='latest';versionUi.msg=t.ok}else{versionUi.status='old';versionUi.msg=t.old}
    }catch(_){versionUi.status='error';versionUi.msg=t.repoFail}
    $('versionBtn').disabled=false;
    $('versionBox').className='versionBox show '+(versionUi.status==='latest'?'ok':versionUi.status==='error'?'error':'warn');
    $('versionBox').innerHTML=`<b>${t.installedVer}</b> ${versionUi.installed||'-'} &nbsp; · &nbsp; <b>${t.repoVer}</b> ${versionUi.repo||'-'}<br>${versionUi.msg}`;
    render();
  };
  document.querySelectorAll('[data-lang]').forEach(b=>b.onclick=()=>{localStorage.setItem('edgeConnectorLanguage',b.dataset.lang);render()});

  function sync(){callback();if(!installed())sessionStorage.removeItem(DELETE_NOTICE);render()}
  try{channel=new BroadcastChannel('edge-connector-state');channel.onmessage=sync}catch(_){}
  window.addEventListener('storage',e=>{if(e.key===STATE_KEY)sync()});window.addEventListener('focus',sync);window.addEventListener('pageshow',sync);
  let last=state(),n=0;const timer=setInterval(()=>{const s=state();if(s!==last){last=s;sync()}if(++n>=10)clearInterval(timer)},3000);
  render();
})();

// ------------------------------------------------------------

(() => {
  const tree=document.querySelector('.workflow-tree.explorer-tree');
  const svg=document.getElementById('workflowTreeSvg');
  if(!tree || !svg) return;

  const root=tree.querySelector('.tree-root-node');
  const admin=tree.querySelector('.local-admin-node');
  const trace=tree.querySelector('.trace-node');
  const mib=tree.querySelector('.mib-node');
  const sysinfo=tree.querySelector('.sysinfo-node');
  const live=tree.querySelector('.live-branch > .tree-child');
  const analysis=tree.querySelector('.level-3 > .tree-child');

  const ns='http://www.w3.org/2000/svg';

  function rect(el,base){
    const r=el.getBoundingClientRect();
    return {
      left:r.left-base.left,
      top:r.top-base.top,
      right:r.right-base.left,
      bottom:r.bottom-base.top,
      width:r.width,
      height:r.height,
      cy:r.top-base.top+Math.min(26,r.height/2)
    };
  }

  function addRoundedLink(parent,child,klass){
    if(!parent || !child) return;
    const base=tree.getBoundingClientRect();
    const p=rect(parent,base);
    const c=rect(child,base);

    // Explorer-like rail sits in the indentation gutter.
    const x=Math.max(p.left+12,c.left-22);
    const startY=p.bottom;
    const endY=c.top+25;
    const endX=c.left;
    const radius=Math.max(5,Math.min(9,Math.abs(endX-x)/2,Math.abs(endY-startY)/2));

    let d;
    if(endY > startY + radius*2){
      // Vertical rail -> soft 90 degree elbow -> child card.
      d=`M ${x} ${startY}
         V ${endY-radius}
         Q ${x} ${endY} ${x+radius} ${endY}
         H ${endX}`;
    }else{
      // Cards are unusually close: use a small smooth bend rather than a sharp line.
      const midY=(startY+endY)/2;
      d=`M ${x} ${startY}
         V ${midY}
         Q ${x} ${endY} ${x+radius} ${endY}
         H ${endX}`;
    }

    const path=document.createElementNS(ns,'path');
    path.setAttribute('d',d.replace(/\s+/g,' ').trim());
    path.setAttribute('class',klass);
    svg.appendChild(path);
  }

  function drawTree(){
    if(!root || !admin || !trace || !mib || !sysinfo || !live || !analysis) return;

    const w=Math.max(1,tree.clientWidth);
    const h=Math.max(1,tree.scrollHeight);
    svg.setAttribute('viewBox',`0 0 ${w} ${h}`);
    svg.setAttribute('width',w);
    svg.setAttribute('height',h);
    svg.innerHTML='';

    // Root branches.
    addRoundedLink(root,admin,'tree-link-neutral');
    addRoundedLink(root,trace,'tree-link-neutral');
    addRoundedLink(root,mib,'tree-link-neutral');
    addRoundedLink(root,sysinfo,'tree-link-neutral');

    // Trace workflow: subtle red connector.
    addRoundedLink(trace,live,'tree-link-trace');
    addRoundedLink(live,analysis,'tree-link-trace');
  }

  let raf=0;
  function scheduleDraw(){
    cancelAnimationFrame(raf);
    raf=requestAnimationFrame(()=>requestAnimationFrame(drawTree));
  }

  window.addEventListener('resize',scheduleDraw,{passive:true});
  window.addEventListener('pageshow',scheduleDraw);
  document.querySelectorAll('[data-lang]').forEach(btn=>{
    btn.addEventListener('click',()=>setTimeout(scheduleDraw,30));
  });

  if('ResizeObserver' in window){
    const ro=new ResizeObserver(scheduleDraw);
    [tree,root,admin,trace,mib,sysinfo,live,analysis].forEach(el=>el&&ro.observe(el));
  }

  if(document.fonts?.ready) document.fonts.ready.then(scheduleDraw);
  scheduleDraw();
})();
