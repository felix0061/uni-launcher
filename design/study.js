/* Presentational design boards only. There are no vehicle or application integrations. */
const icon = (name, cls = '') => `<svg class="icon ${cls}" aria-hidden="true"><use href="#${name}"/></svg>`;
const params = new URLSearchParams(location.search);
let selectedStyle = ['calm','warm','ice'].includes(params.get('style')) ? params.get('style') : 'calm';
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

function screen(theme) {
  return `<div class="screen ${theme} ${selectedStyle}" role="img" aria-label="领克05 ${theme==='dark'?'深色':'浅色'}卡片式首页视觉稿，所有数据均为示意">
    <div class="oem-status"><span>09:41</span><div class="status-right">${icon('bluetooth')}<span class="signal"><i></i><i></i><i></i><i></i></span><span>4G</span><span>LYNK & CO</span></div></div>
    <div class="desktop">
      <div class="desk-head"><div class="brand">LYNK & CO<i></i><span>05 / DRIVE</span></div><div class="greeting">${icon('cloud')}<span>24° 多云</span><i></i><span>10月24日 · 周六</span></div></div>
      <div class="desk-content">
        <div class="side-rail"><div class="rail-item active">${icon('home')}<span>首页</span></div><div class="rail-item">${icon('nav')}<span>导航</span></div><div class="rail-item">${icon('music')}<span>音乐</span></div><div class="rail-item">${icon('apps')}<span>应用</span></div></div>
        <div class="nav-card">${map}<div class="direction-box"><div class="turn-icon">${icon('turn')}</div><div class="direction-copy"><b>600 米后右转</b><p>进入城市大道</p></div></div><div class="compass">N</div><div class="map-tool"><span>＋</span><span>−</span></div><div class="destination"><div><small>前往 · 城市中心</small><div class="arrival"><b>10:08 到达</b><span>27 分钟 · 12.6 公里</span></div></div><div class="dest-arrow">${icon('nav')}</div></div></div>
        <div class="music-column"><div class="music-card"><div class="card-label"><span>正在播放</span><span class="source"><i class="source-dot"></i>QQ 音乐</span></div><div class="track"><div class="cover">${art}</div><div><b>向海而行</b><p>Coastline<br>晨间驾驶歌单</p></div></div><div class="music-progress"><div class="track-line"></div><div class="music-times"><span>00:46</span><span>04:18</span></div></div><div class="player-controls">${icon('heart')}<div class="transport">${icon('back')}<div class="pause-disc">${icon('pause')}</div>${icon('next')}</div><span class="loop">↻</span></div></div>
        <div class="quick-card"><div class="card-label"><span>常用</span><span>···</span></div><div class="quick-items">${[['fan','空调'],['car','车辆'],['phone','电话'],['settings','设置']].map(([i,t])=>`<div class="quick-item"><span class="quick-icon">${icon(i)}</span><span>${t}</span></div>`).join('')}</div></div></div>
      </div>
    </div>
    <div class="oem-bottom"><div class="oem-group"><span class="oem-item">${icon('car')}车辆</span><span class="oem-item">${icon('camera')}360°</span></div><span class="oem-divider"></span><div class="temp-inline"><span>−</span><b>22.5<sup>°</sup></b><span>＋</span></div><div class="oem-mode">${icon('fan')}<span class="mode-on">AUTO</span><span>A/C</span>${icon('recirc')}</div><div class="temp-inline"><span>−</span><b>22.5<sup>°</sup></b><span>＋</span></div><span class="oem-divider"></span><div class="oem-group">${icon('seat')}${icon('defrost')}</div></div>
  </div>`;
}

function climate(theme) {
  return `<div class="climate-panel screen ${theme} ${selectedStyle}" role="img" aria-label="${theme==='dark'?'深色':'浅色'}双区空调卡片视觉稿">
    <div class="climate-heading"><strong>座舱舒适</strong><span>自动空调</span></div>
    <div class="climate-zones"><div class="zone"><div class="zone-label">主驾</div><div class="zone-value"><span>−</span><b>22.5<sup>°</sup></b><span>＋</span></div></div><span class="sync">双区同步</span><div class="zone"><div class="zone-label">副驾</div><div class="zone-value"><span>−</span><b>22.5<sup>°</sup></b><span>＋</span></div></div></div>
    <div class="fan-level">${icon('fan')}<span>风量</span><div class="fan-track">${Array.from({length:7},(_,i)=>`<i class="${i<3?'on':''}"></i>`).join('')}</div><span>3 档</span></div>
    <div class="climate-modes"><div class="climate-mode active">AUTO</div><div class="climate-mode active">A/C</div><div class="climate-mode">${icon('recirc')}内循环</div><div class="climate-mode">${icon('defrost')}除霜</div></div>
  </div>`;
}

function resize() {
  document.querySelectorAll('.screen-wrap').forEach(el=>{el.firstElementChild.style.transform=`scale(${el.clientWidth/1920})`;});
  document.querySelectorAll('.climate-wrap').forEach(el=>{el.firstElementChild.style.transform=`scale(${el.clientWidth/900})`;});
}
function render() {
  document.querySelectorAll('[data-style]').forEach(el=>{const chosen=el.dataset.style===selectedStyle;el.classList.toggle('chosen',chosen);el.setAttribute('aria-pressed',String(chosen));});
  document.querySelector('.spec-grid strong').textContent=selectedStyle==='warm'?'32 px':selectedStyle==='ice'?'18 px':'28 px';
  document.getElementById('screens').innerHTML=['dark','light'].map(theme=>`<figure class="screen-figure"><figcaption class="screen-caption"><b>${theme==='dark'?'夜航 / NIGHT':'晨光 / DAY'}</b><span>1920 × 1080 · 视觉设计稿</span></figcaption><div class="screen-wrap">${screen(theme)}</div></figure>`).join('');
  document.getElementById('climate-studies').innerHTML=['dark','light'].map(theme=>`<figure class="climate-figure"><figcaption>${theme==='dark'?'深色空调层':'浅色空调层'}</figcaption><div class="climate-wrap">${climate(theme)}</div></figure>`).join('');
  const view=params.get('view');
  if(view==='single'||view==='component') {
    document.body.classList.add('single');
    if(view==='component')document.body.classList.add('component');
    document.getElementById('single-screen').innerHTML=view==='component'?climate(params.get('theme')==='light'?'light':'dark'):screen(params.get('theme')==='light'?'light':'dark');
  }
  if(view==='pair')document.body.classList.add('pair');
  if(view==='directions') {
    document.body.classList.add('directions-view');
    const original=selectedStyle;
    document.getElementById('single-screen').innerHTML=`<div class="comparison-head"><span>LYNK 05 / VISUAL DIRECTIONS</span><h1>三种气质，同一套卡片秩序。</h1><p>视觉风格对比 · 所有画面均为设计示意</p></div><div class="comparison-grid">${[['calm','A · 冷灰青绿','推荐 / 克制的科技感'],['warm','B · 暖白石墨','温润 / 更柔和的座舱感'],['ice','C · 石墨冰蓝','利落 / 更鲜明的运动感']].map(([style,title,note])=>{selectedStyle=style;return `<section class="comparison-column"><h2>${title}</h2><p>${note}</p><div class="screen-wrap">${screen('dark')}</div><div class="screen-wrap">${screen('light')}</div></section>`;}).join('')}</div>`;
    selectedStyle=original;
  }
  requestAnimationFrame(resize);
}
document.querySelectorAll('[data-style]').forEach(el=>el.addEventListener('click',()=>{selectedStyle=el.dataset.style;const url=new URL(location.href);url.searchParams.set('style',selectedStyle);history.replaceState(null,'',url);render();}));
window.addEventListener('resize',resize);
new ResizeObserver(resize).observe(document.querySelector('.board'));
render();
