/* Presentational design boards only. There are no vehicle or application integrations. */
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
  return `<div class="dock-lane"><div class="music-dock">
    <div class="dock-navigation"><span class="dock-control dock-home" title="首页">${icon('home')}</span><span class="dock-apps">${icon('apps')}<span>全部应用</span></span></div>
    <span class="dock-separator"></span>
    <div class="dock-media"><div class="dock-track"><div class="cover">${art}</div><div class="dock-track-copy"><b>向海而行</b><p>Coastline · QQ 音乐</p></div></div><div class="dock-transport"><span class="dock-control" title="上一首">${icon('back')}</span><span class="dock-play" title="播放或暂停">${icon('pause')}</span><span class="dock-control" title="下一首">${icon('next')}</span></div></div>
    <span class="dock-separator"></span>
    <div class="dock-climate"><div class="dock-zone"><b>22.5<sup>°</sup></b><span>主驾</span></div><div class="dock-auto">${icon('fan')}<span>AUTO</span></div><div class="dock-zone"><b>22.5<sup>°</sup></b><span>副驾</span></div></div>
    <span class="dock-separator"></span>
    <div class="dock-vehicle"><span class="dock-control" title="车辆">${icon('car')}</span><span class="dock-control" title="360全景">${icon('camera')}</span></div>
  </div></div>`;
}

function screen(theme) {
  return `<div class="screen ${theme} calm glass" role="img" aria-label="领克05 ${theme==='dark'?'深色':'浅色'}毛玻璃全宽首页与96像素音乐底栏视觉稿，所有数据均为示意">
    <div class="oem-status"><div class="status-left"><b>09:41</b><span>LYNK & CO / 05</span></div><div class="status-right"><span class="status-weather">${icon('cloud')}24° 多云</span>${icon('bluetooth')}<span class="signal"><i></i><i></i><i></i><i></i></span><span>4G</span></div></div>
    <div class="desktop"><div class="desk-content">
      <div class="nav-card">${map}<div class="direction-box"><div class="turn-icon">${icon('turn')}</div><div class="direction-copy"><b>600 米后右转</b><p>进入城市大道</p></div></div><div class="compass">N</div><div class="map-tool"><span>＋</span><span>−</span></div><div class="destination"><div><small>前往 · 城市中心</small><div class="arrival"><b>10:08 到达</b><span>27 分钟 · 12.6 公里</span></div></div><div class="dest-arrow">${icon('nav')}</div></div></div>
      <div class="music-column"><div class="music-card"><div class="card-label"><span>正在播放</span><span class="source"><i class="source-dot"></i>QQ 音乐</span></div><div class="listening"><div class="cover hero-cover">${art}</div><h3>向海而行</h3><p>Coastline · 晨间驾驶歌单</p><div class="music-progress"><div class="track-line"></div><div class="music-times"><span>00:46</span><span>04:18</span></div></div><div class="listening-note"><span>播放队列 · 12 首</span>${icon('heart')}</div></div></div>
      <div class="quick-card"><div class="card-label"><span>常用</span><span>···</span></div><div class="quick-items">${[['nav','导航'],['fan','空调'],['phone','电话'],['settings','设置']].map(([i,t])=>`<div class="quick-item"><span class="quick-icon">${icon(i)}</span><span>${t}</span></div>`).join('')}</div></div></div>
    </div></div>
    ${dock()}
  </div>`;
}

function dockStudy(theme) {
  return `<div class="screen dock-study ${theme} calm glass" role="img" aria-label="${theme==='dark'?'深色':'浅色'}96像素毛玻璃音乐底栏，包含全部应用、歌曲信息和播放控制"><span class="dock-mini-label">${theme==='dark'?'NIGHT / 深色音乐底栏':'DAY / 浅色音乐底栏'}</span>${dock()}</div>`;
}

function climate(theme) {
  return `<div class="climate-panel screen ${theme} calm glass" role="img" aria-label="${theme==='dark'?'深色':'浅色'}双区空调毛玻璃卡片视觉稿"><div class="climate-glass">
    <div class="climate-heading"><strong>座舱舒适</strong><span>自动空调</span></div>
    <div class="climate-zones"><div class="zone"><div class="zone-label">主驾</div><div class="zone-value"><span>−</span><b>22.5<sup>°</sup></b><span>＋</span></div></div><span class="sync">双区同步</span><div class="zone"><div class="zone-label">副驾</div><div class="zone-value"><span>−</span><b>22.5<sup>°</sup></b><span>＋</span></div></div></div>
    <div class="fan-level">${icon('fan')}<span>风量</span><div class="fan-track">${Array.from({length:7},(_,i)=>`<i class="${i<3?'on':''}"></i>`).join('')}</div><span>3 档</span></div>
    <div class="climate-modes"><div class="climate-mode active">AUTO</div><div class="climate-mode active">A/C</div><div class="climate-mode">${icon('recirc')}内循环</div><div class="climate-mode">${icon('defrost')}除霜</div></div>
  </div></div>`;
}

function resize() {
  document.querySelectorAll('.screen-wrap').forEach(el=>{el.firstElementChild.style.transform=`scale(${el.clientWidth/1920})`;});
  document.querySelectorAll('.climate-wrap').forEach(el=>{el.firstElementChild.style.transform=`scale(${el.clientWidth/900})`;});
  document.querySelectorAll('.dock-wrap').forEach(el=>{el.firstElementChild.style.transform=`scale(${el.clientWidth/1920})`;});
}
function render() {
  document.getElementById('screens').innerHTML=['dark','light'].map(theme=>`<figure class="screen-figure"><figcaption class="screen-caption"><b>${theme==='dark'?'夜航 / NIGHT':'晨光 / DAY'}</b><span>V02 · 毛玻璃 / 全宽卡片 / 音乐底栏</span></figcaption><div class="screen-wrap">${screen(theme)}</div></figure>`).join('');
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
