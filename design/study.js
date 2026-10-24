/* Browser design prototype. No vehicle or application integrations. */
const icon = (name, cls = '') => `<svg class="icon ${cls}" aria-hidden="true"><use href="#${name}"/></svg>`;
const params = new URLSearchParams(location.search);
const art = `<svg viewBox="0 0 142 142" aria-hidden="true"><rect width="142" height="142" fill="#d3bd97"/><circle cx="108" cy="36" r="26" fill="#f6d59b"/><path d="M-10 88Q43 42 93 81T165 77V142H0" fill="#607f89"/><path d="M-10 105Q33 66 80 107T165 95V142H0" fill="#1f4a5d"/><path d="M-10 135Q55 92 155 132" fill="none" stroke="#d6dfd3" stroke-width="2"/><text x="12" y="24" font-family="sans-serif" font-size="10" fill="#244452" letter-spacing="2">COASTLINE</text></svg>`;
const map = `<svg class="map" viewBox="0 0 1144 732" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
  <rect class="block" x="-10" y="-10" width="1180" height="760"/>
  <path class="water" d="M1080-10C960 180 1120 260 975 425S960 620 1144 750H1200V-10Z"/>
  <path class="park" d="m55 240 250-10 64 148-94 129L44 452Z"/><path class="park" d="m720 410 170 12 17 152-206 30Z"/>
  <g class="road minor"><path d="M-10 235 1144 235M-10 390 1144 390M-10 575 1144 575M180-10v760M330-10v760M780-10v760M950-10v760"/><path d="M-10 732 145 520 409 310 726-10M-10 20l1154 600"/></g>
  <g class="road"><path d="M-10 145h1164M-10 470h1164M487-10v760M650-10v760"/><path d="M-10 650Q380 570 514 311T1030-10"/></g>
  <text class="label" x="110" y="337">城市公园</text><text class="label" x="724" y="530">文化广场</text><text class="label" x="710" y="205">城市大道</text><text class="label" x="225" y="440">滨河路</text><text class="label" x="836" y="350" transform="rotate(90 836 350)">环城东路</text>
  <path class="route-edge" d="M650 520V470H780V145H960"/><path class="route" d="M650 520V470H780V145H960"/>
  <circle cx="960" cy="145" r="13" fill="var(--accent)" stroke="var(--surface)" stroke-width="6"/>
  <circle cx="650" cy="520" r="48" fill="var(--accent)" opacity=".12"/><circle cx="650" cy="520" r="30" fill="var(--surface)"/>
  <path d="m650 495 17 41-17-8-17 8Z" fill="var(--accent)"/>
</svg>`;


function dock() {
  const m=mediaState();
  const zone=(id,label)=>`<div class="dock-temp-zone">${actionButton('temp-down','minus','降低'+label+'温度','dock-temp-step',`data-zone="${id}"`)}<button class="dock-zone" data-action="climate" aria-label="${label}空调 ${temperature(id)} 度" title="${label}空调"><b>${temperature(id)}<sup>°</sup></b></button>${actionButton('temp-up','plus','升高'+label+'温度','dock-temp-step',`data-zone="${id}"`)}</div>`;
  return `<div class="dock-lane"><div class="music-dock">
    <div class="dock-navigation" data-dock-group="navigation">${actionButton('home','home','首页；长按进入桌面设置','dock-control dock-home','data-home-hold')}${actionButton('apps','apps','全部应用','dock-control')}</div>
    <span class="dock-separator"></span>
    <div class="dock-climate ${ui.climate.power?'':'off'}" data-dock-group="climate">${zone('left','主驾')}${actionButton('climate','fan','空调与风量','dock-control dock-fan')}${zone('right','副驾')}${actionButton('climate-power','power','空调开关','dock-control '+(ui.climate.power?'accent':''))}</div>
    <span class="dock-separator"></span>
    <div class="dock-transport" data-dock-group="transport">${actionButton('previous','back','上一首','dock-control')}${actionButton('toggle-play',ui.playing?'pause':'play',ui.playing?'暂停':'播放','dock-play')}${actionButton('next','next','下一首','dock-control')}</div>
    <button class="dock-track dock-info" data-action="music-info" data-dock-group="info" aria-label="音乐信息，打开详情"><div class="cover">${art}</div><div class="dock-track-copy"><b>${m.title}</b><p>${m.artist} · 原车媒体中心</p></div></button>
    <span class="dock-separator"></span>
    <div data-dock-group="vehicle">${actionButton('vehicle','car','车辆信息','dock-control')}</div>
    <div data-dock-group="camera">${actionButton('camera','camera','360 影像','dock-control')}</div>
  </div></div>`;
}

function screen(theme,options={}) {
  const staticView=options.static===true,editing=options.editing||(!staticView&&ui.editing);
  const items=staticView?defaultCards():cards,page=staticView?(options.page||0):ui.page;
  const count=staticView?Math.max(1,...items.map(c=>c.page+1),page+1):pageCount;
  return `<div class="screen ${theme} calm glass v03-home ${editing?'editing':''}" style="${themeStyle(theme)}" aria-label="领克05 ${theme==='dark'?'深色':'浅色'}自定义卡片桌面，示例数据">
    ${statusBar()}
    <div class="desktop">${editing?editorToolbar():''}<div class="card-grid">${items.filter(c=>c.page===page).map(c=>widget(c,editing)).join('')}${!items.some(c=>c.page===page)?`<button class="empty-grid" data-action="open-library">${icon('plus')}<strong>添加一张卡片</strong><span>从导航、音乐、天气开始</span></button>`:''}</div>${pageDots(page,count,editing)}</div>
    ${dock()}${staticView?'':modalMarkup(theme)}
  </div>`;
}
function dockStudy(theme) {
  return `<div class="screen dock-study ${theme} calm glass" style="${themeStyle(theme)}" role="img" aria-label="${theme==='dark'?'深色':'浅色'}96像素纯图标音乐底栏，长按首页进入桌面设置"><span class="dock-mini-label">${theme==='dark'?'NIGHT / 深色音乐底栏':'DAY / 浅色音乐底栏'}</span>${dock()}</div>`;
}


function climate(theme) {
  return `<div class="climate-panel screen ${theme} calm glass" style="${themeStyle(theme)}" role="img" aria-label="${theme==='dark'?'深色':'浅色'}双区空调毛玻璃卡片视觉稿"><div class="climate-glass">
    <div class="climate-heading"><strong>座舱舒适</strong><span>自动空调</span></div>
    <div class="climate-zones"><div class="zone"><div class="zone-label">主驾</div><div class="zone-value"><span>−</span><b>22.5<sup>°</sup></b><span>＋</span></div></div><span class="sync">双区同步</span><div class="zone"><div class="zone-label">副驾</div><div class="zone-value"><span>−</span><b>22.5<sup>°</sup></b><span>＋</span></div></div></div>
    <div class="fan-level">${icon('fan')}<span>风量</span><div class="fan-track">${Array.from({length:7},(_,i)=>`<i class="${i<3?'on':''}"></i>`).join('')}</div><span>3 档</span></div>
    <div class="climate-modes"><div class="climate-mode active">AUTO</div><div class="climate-mode active">A/C</div><div class="climate-mode">${icon('recirc')}内循环</div><div class="climate-mode">${icon('defrost')}除霜</div></div>
  </div></div>`;
}

function resize() {
  document.querySelectorAll('.screen-wrap').forEach(el=>{el.firstElementChild.style.transform=`scale(${el.clientWidth/1920})`;});
  document.querySelectorAll('.climate-wrap').forEach(el=>{el.firstElementChild.style.transform=`scale(${el.clientWidth/900})`;});
  document.querySelectorAll('.mini-screen-wrap').forEach(el=>{el.firstElementChild.style.transform=`scale(${el.clientWidth/1920})`;});
  document.querySelectorAll('.gallery-wrap').forEach(el=>{el.firstElementChild.style.transform=`scale(${el.clientWidth/1920})`;});
  document.querySelectorAll('.dock-wrap').forEach(el=>{el.firstElementChild.style.transform=`scale(${el.clientWidth/1920})`;});
}
function render() {
  document.getElementById('screens').innerHTML=['dark','light'].map(theme=>`<figure class="screen-figure"><figcaption class="screen-caption"><b>${theme==='dark'?'夜航 / NIGHT':'晨光 / DAY'}</b><span>V04 · 原厂卡片 / 自由布局 / 图标底栏</span></figcaption><div class="screen-wrap">${screen(theme,{static:true})}</div></figure>`).join('');
  document.getElementById('settings-studies').innerHTML=['dark','light'].map(theme=>`<figure class="screen-figure"><figcaption class="screen-caption"><b>${theme==='dark'?'深色':'浅色'} · 桌面设置</b><a href="?view=settings&theme=${theme}">打开交互预览 ↗</a></figcaption><div class="screen-wrap">${settingsScreen(theme)}</div></figure>`).join('');
  document.getElementById('edit-study').innerHTML=`<div class="screen-wrap">${screen('dark',{static:true,editing:true})}</div>`;
  document.getElementById('oem-studies').innerHTML=['dark','light'].map(theme=>`<figure class="screen-figure"><figcaption class="screen-caption"><b>${theme==='dark'?'深色':'浅色'} · 原厂卡片样式总览</b><a href="?view=cards&theme=${theme}">查看完整卡片 ↗</a></figcaption><div class="gallery-wrap">${oemGallery(theme)}</div></figure>`).join('');
  document.getElementById('secondary-studies').innerHTML=`<div class="screen-wrap">${screen('dark',{static:true,page:1})}</div>`;
  document.getElementById('dock-studies').innerHTML=['dark','light'].map(theme=>`<div class="dock-wrap">${dockStudy(theme)}</div>`).join('');
  document.getElementById('climate-studies').innerHTML=['dark','light'].map(theme=>`<figure class="climate-figure"><figcaption>${theme==='dark'?'深色空调层':'浅色空调层'}</figcaption><div class="climate-wrap">${climate(theme)}</div></figure>`).join('');
  const view=params.get('view');
  if(view==='single'||view==='component') {
    document.body.classList.add('single');
    if(view==='component')document.body.classList.add('component');
    document.getElementById('single-screen').innerHTML=view==='component'?climate(params.get('theme')==='light'?'light':'dark'):screen(params.get('theme')==='light'?'light':'dark');
  }
  if(view==='pair'||view==='directions')document.body.classList.add('pair');
  if(view==='dock') {
    document.body.classList.add('dock-only');
    document.getElementById('single-screen').innerHTML=dockStudy('dark')+dockStudy('light');
  }
  requestAnimationFrame(resize);
}
window.addEventListener('resize',resize);
new ResizeObserver(resize).observe(document.querySelector('.board'));
render();
initCustomization();
