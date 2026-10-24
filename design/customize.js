// V04 browser design prototype. Official provider content is not connected.
const designQuery = new URLSearchParams(location.search);
const exportMode = designQuery.get('export') === '1';
const palettePresets = [
  {id:'mint', name:'青屿', seed:'#31B9A2', dark:'#71E4CE', light:'#087568'},
  {id:'blue', name:'冰川', seed:'#4B92DE', dark:'#8FC8FF', light:'#245F9E'},
  {id:'violet', name:'鸢尾', seed:'#9570D5', dark:'#CEB5FF', light:'#7550A4'},
  {id:'amber', name:'琥珀', seed:'#D49A47', dark:'#F4CF8A', light:'#8B5E1E'},
  {id:'rose', name:'玫瑰', seed:'#CB748A', dark:'#F4B1C4', light:'#98465F'}
];
const defaultCards = () => [
  {id:'nav-1',type:'nav',title:'导航',x:0,y:0,w:8,h:6,page:0},
  {id:'music-1',type:'music',title:'正在播放',x:8,y:0,w:4,h:4,page:0},
  {id:'weather-1',type:'weather',title:'杭州',city:'杭州',forecast:false,x:8,y:4,w:4,h:2,page:0},
  {id:'member-1',type:'member',title:'账号',x:0,y:0,w:4,h:6,page:1},
  {id:'cleanup-1',type:'cleanup',title:'系统清理',x:4,y:0,w:4,h:3,page:1},
  {id:'calendar-1',type:'calendar',title:'日历',x:4,y:3,w:4,h:3,page:1},
  {id:'tpms-1',type:'tpms',title:'胎压',x:8,y:0,w:4,h:6,page:1}
];
const cardCatalog = {
  nav:{name:'导航',icon:'nav',description:'原车导航与引导信息',source:'原车导航服务',oem:true,w:8,h:6,minW:6,minH:3},
  music:{name:'音乐',icon:'music',description:'原车媒体与播放信息',source:'原车媒体中心',oem:true,w:4,h:4,minW:3,minH:2},
  weather:{name:'天气',icon:'cloud',description:'原车城市与天气信息',source:'原车天气',oem:true,w:4,h:2,minW:3,minH:2},
  ...oemCardDefinitions,
  clock:{name:'时钟',icon:'clock',description:'时间、日期与星期',w:4,h:2,minW:3,minH:2},
  shortcuts:{name:'快捷应用',icon:'apps',description:'你常用的四个应用',w:4,h:2,minW:3,minH:2},
  vehicle:{name:'车辆信息',icon:'car',description:'车辆信息兼容卡片',source:'原车车辆信息',w:4,h:3,minW:3,minH:2}
};
const preferences = {palette:'mint',custom:'#38A4A0',mode:'system',radius:28,glass:false,pageTransition:'none'};
let cards = defaultCards();
let pageCount=2;
if (!exportMode) {
  try {
    const cached=JSON.parse(localStorage.getItem('lynk-design-v04')||localStorage.getItem('lynk-design-v03')||'null');
    if(cached && [3,4].includes(cached.version)) {
      if([...palettePresets.map(p=>p.id),'custom'].includes(cached.preferences?.palette)) Object.assign(preferences,cached.preferences);
      if(Array.isArray(cached.cards) && cached.cards.every(c=>cardCatalog[c.type] && ['x','y','w','h','page'].every(k=>Number.isInteger(c[k])) && c.x>=0 && c.y>=0 && c.w>=cardCatalog[c.type].minW && c.h>=cardCatalog[c.type].minH && c.x+c.w<=12 && c.y+c.h<=6 && c.page>=0)) cards=cached.cards;
      pageCount=Math.max(1,...cards.map(c=>c.page+1),Number.isInteger(cached.pageCount)?cached.pageCount:1);
    }
  } catch (_) {}
}
const ui={view:'home',page:0,editing:false,modal:null,selected:null,tab:'appearance',snapshot:null,undo:null,toast:'',playing:true,trackIndex:0,climate:{left:22.5,right:22.5,fan:3,power:true,auto:true,ac:true,sync:false,recirc:false,driverHeat:0,driverVent:0,passengerHeat:0}};
preferences.radius=Number.isFinite(+preferences.radius)?Math.max(0,Math.min(40,Math.round(+preferences.radius))):28;
preferences.glass=preferences.glass===true;
function safe(value) {return String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
function persistDesign() {if(!exportMode)try{localStorage.setItem('lynk-design-v04',JSON.stringify({version:4,preferences,cards,pageCount}));}catch(_){}}
function rgb(hex) {return (hex.match(/[a-f0-9]{2}/ig)||['38','A4','A0']).slice(0,3).map(n=>parseInt(n,16));}
function mix(hex,target,amount) {return '#'+rgb(hex).map((v,i)=>Math.round(v*(1-amount)+target[i]*amount).toString(16).padStart(2,'0')).join('');}
function themeStyle(theme) {
  const p=palettePresets.find(p=>p.id===preferences.palette);
  const seed=p?.seed||preferences.custom;
  const accent=p?p[theme]:(theme==='light'?mix(seed,[0,0,0],.42):mix(seed,[255,255,255],.42));
  const text=theme==='light'?'#FFFFFF':mix(seed,[0,0,0],.80);
  return `--accent:${accent};--accent-text:${text};--scene-rgb:${rgb(seed).join(',')};--card-radius:${preferences.radius}px;--surface-filter:${preferences.glass?'blur(28px) saturate(115%)':'none'};--overlay-filter:${preferences.glass?'blur(12px)':'none'};`;
}
function activeTheme() {
  if(preferences.mode==='light'||preferences.mode==='dark')return preferences.mode;
  const requested=designQuery.get('theme');
  return requested==='light'?'light':requested==='dark'?'dark':matchMedia('(prefers-color-scheme: light)').matches?'light':'dark';
}
function actionButton(action, symbol, label, cls='', data='') {
  return `<button class="${cls}" data-action="${action}" aria-label="${label}" title="${label}" ${data}>${icon(symbol)}</button>`;
}
function statusBar() {
  return `<div class="oem-status"><div class="status-left"><b>09:41</b><span>LYNK & CO / 05</span></div><div class="status-right"><span class="status-weather">${icon('cloud')}24° 多云</span>${icon('bluetooth')}<span class="signal"><i></i><i></i><i></i><i></i></span><span>4G</span></div></div>`;
}
function cardBody(card) {
  if(oemCardDefinitions[card.type]||card.type==='vehicle')return oemCardBody(card);
  switch(card.type) {
    case 'nav':return `${map}<div class="direction-box"><div class="turn-icon">${icon('turn')}</div><div class="direction-copy"><b>600 米后右转</b><p>进入城市大道</p></div></div><div class="compass">N</div><div class="map-tool"><span>＋</span><span>−</span></div><div class="destination"><div><small>前往 · 城市中心</small><div class="arrival"><b>10:08 到达</b><span>27 分钟 · 12.6 公里</span></div></div><div class="dest-arrow">${icon('nav')}</div></div>`;
    case 'music':{const m=mediaState();return `<div class="card-label"><span>${safe(card.title)}</span><span class="source"><i class="source-dot"></i>原车媒体</span></div><div class="listening"><div class="cover hero-cover">${art}</div><div class="song-copy"><h3>${m.title}</h3><p>${m.artist} · ${m.collection}</p><div class="lyrics-inline">风把远方带进了呼吸</div></div><div class="music-progress"><div class="track-line"></div><div class="music-times"><span>00:46</span><span>04:18</span></div></div><div class="listening-note"><span>原车媒体中心 · 样式示例</span>${actionButton('music-info','arrow-right','打开音乐详情','media-detail-button')}</div></div>`;}
    case 'weather':return `<div class="weather-heading"><span>${icon('pin')}${safe(card.city||card.title||'杭州')}</span><span>天气示例</span></div><div class="weather-current"><div><b>24<sup>°</sup></b><span>多云</span></div><div class="weather-art">${icon('sun')}${icon('cloud')}</div></div><div class="weather-foot"><span>原车天气</span><span>等待官方天气同步</span></div>`;
    case 'clock':return `<div class="card-label"><span>${safe(card.title)}</span>${icon('clock')}</div><div class="clock-time">09<span>:</span>41</div><div class="clock-date">10 月 24 日 · 星期六</div>`;
    case 'shortcuts':return `<div class="card-label"><span>${safe(card.title)}</span>${icon('apps')}</div><div class="quick-items">${[['nav','导航'],['phone','电话'],['music','音乐'],['settings','系统设置']].map(([i,t])=>`<div class="quick-item"><span class="quick-icon">${icon(i)}</span><span>${t}</span></div>`).join('')}</div>`;

  }
}
function widget(card,editing) {
  return `<article class="widget-card ${card.type}-card ${card.h<=3?'compact':''} ${editing?'editable-card':''}" data-card="${safe(card.id)}" data-type="${card.type}" data-oem="${!!cardCatalog[card.type].oem}" style="grid-column:${card.x+1}/span ${card.w};grid-row:${card.y+1}/span ${card.h}" aria-label="${safe(cardCatalog[card.type].name)}卡片">
    <div class="widget-content">${cardBody(card)}</div>
    ${editing?`<div class="card-edit-tools"><button class="card-move" aria-label="移动${safe(cardCatalog[card.type].name)}卡片">${icon('move')}<span>${safe(cardCatalog[card.type].name)}</span></button><span class="size-badge">${card.w} × ${card.h}</span>${actionButton('edit-card','edit','编辑卡片','tiny-button',`data-id="${safe(card.id)}"`)}${actionButton('delete-card','trash','删除卡片','tiny-button',`data-id="${safe(card.id)}"`)}</div><button class="resize-handle" aria-label="调整${safe(cardCatalog[card.type].name)}卡片大小">${icon('resize')}</button>`:''}
  </article>`;
}
function editorToolbar() {
  return `<div class="editor-toolbar"><div><strong>编辑桌面</strong><span>拖动卡片移动 · 拖动右下角缩放</span></div><div class="editor-toolbar-actions"><button class="text-button" data-action="cancel-edit">取消</button><button class="outline-button" data-action="open-library">${icon('plus')}添加卡片</button><button class="solid-button" data-action="finish-edit">${icon('check')}完成</button></div></div>`;
}
function pageDots(page,count,editing) {
  if(count<=1&&!editing)return '';
  return `<div class="page-dots">${Array.from({length:count},(_,i)=>`<button data-action="switch-page" data-page="${i}" aria-label="桌面第${i+1}页" class="${page===i?'active':''}"></button>`).join('')}${editing?`<button class="new-page" data-action="new-page" aria-label="新建桌面页">${icon('plus')}</button>`:''}</div>`;
}
function appearanceSettings(theme) {
  return `<div class="settings-main">
    <section class="settings-block"><div class="setting-heading"><h3>显示模式</h3><span>选择适合此刻的明暗</span></div><div class="mode-picker">${[['system','auto-theme','跟随系统'],['light','sun','浅色'],['dark','moon','深色']].map(([id,s,label])=>`<button data-action="set-mode" data-value="${id}" class="${preferences.mode===id?'selected':''}">${icon(s)}${label}${preferences.mode===id?icon('check'):''}</button>`).join('')}</div></section>
    <section class="settings-block theme-block"><div class="setting-heading"><h3>主题配色</h3><span>同步改变强调色与背景氛围</span></div><div class="palette-picker">${palettePresets.map(p=>`<button data-action="set-palette" data-value="${p.id}" class="${preferences.palette===p.id?'selected':''}" aria-label="${p.name}主题色"><span class="palette-chip" style="--swatch:${p.seed}">${preferences.palette===p.id?icon('check'):''}</span><b>${p.name}</b></button>`).join('')}</div><div class="custom-color-row"><div><strong>自定义颜色</strong><span>从取色器选择，或输入 HEX 色值</span></div><div class="custom-color-controls"><label class="color-input-wrap" title="选择自定义颜色"><input type="color" aria-label="自定义主题颜色" value="${safe(preferences.custom)}"><span style="background:${safe(preferences.custom)}"></span></label><input class="hex-input" aria-label="主题 HEX 色值" value="${safe(preferences.custom.toUpperCase())}" maxlength="7" spellcheck="false"><button class="text-button ${preferences.palette==='custom'?'accent':''}" data-action="use-custom">${preferences.palette==='custom'?'已应用':'应用'}</button></div></div></section>
    <section class="settings-block radius-setting"><div><strong>卡片圆角</strong><span>0 为直角 · 默认 28px</span></div><div class="radius-controls"><span>0</span><input type="range" min="0" max="40" step="1" value="${preferences.radius}" data-setting="radius" aria-label="卡片圆角滑杆，0至40像素"><span>40</span><label class="radius-number"><input type="number" min="0" max="40" step="1" value="${preferences.radius}" data-setting="radius" aria-label="卡片圆角像素值"><span>px</span></label></div></section>
  </div><aside class="settings-preview"><div class="setting-heading"><h3>实时预览</h3><span>${theme==='light'?'浅色':'深色'} · ${safe(palettePresets.find(p=>p.id===preferences.palette)?.name||'自定义')}</span></div><div class="mini-screen-wrap">${screen(theme,{static:true})}</div><div class="preview-hint"><span class="preview-color" style="background:var(--accent)"></span><p>路线、播放按钮与选中状态<br>使用同一组主题色</p></div><div class="glass-setting"><div><strong>毛玻璃</strong><span>预览背景模糊 · 关闭仍半透明</span></div><button class="glass-switch" role="switch" aria-label="毛玻璃" aria-checked="${preferences.glass}" data-action="toggle-glass"><span></span></button></div><button class="outline-button" data-action="home">${icon('home')}返回桌面查看</button></aside>`;
}
function layoutSettings() {
  return `<div class="layout-settings settings-block"><div class="layout-copy"><span class="section-kicker">YOUR SPACE</span><h3>桌面，由你编排。</h3><p>长按卡片，进入编辑模式。<br>调整位置和大小，按你的习惯组合信息。</p><button class="solid-button" data-action="start-edit">${icon('edit')}编辑桌面布局</button><button class="text-button" data-action="reset-layout">恢复默认布局</button></div><div class="layout-instructions">${[['plus','添加卡片','从卡片库选择，空间不足时放入新页'],['move','移动与缩放','拖动位置，角点按网格吸附'],['edit','编辑内容','调整卡片名称、尺寸与展示密度'],['trash','移除卡片','移除后可撤销，底栏入口始终保留']].map(([s,t,p])=>`<div>${icon(s)}<span><b>${t}</b><small>${p}</small></span></div>`).join('')}</div></div>`;
}
function sourceSettings() {
  const types=officialCardTypes.filter(t=>t!=='ride');
  return `<div class="source-settings">${types.map(type=>{const c=cardCatalog[type];return `<div class="settings-block source-row">${icon(c.icon)}<div><h3>${c.name}</h3><p>${c.conditional?'按车型能力启用':'保持官方信息来源'}</p></div><span>${c.source}</span><small>待连接</small></div>`;}).join('')}<p class="source-note">样式演示使用占位数据；实际显示内容以原车应用提供的信息为准。</p></div>`;
}
function settingsScreen(theme) {
  return `<div class="screen glass ${theme} settings-screen" style="${themeStyle(theme)}">${statusBar()}<div class="settings-content"><header class="settings-heading">${actionButton('home','arrow-left','返回桌面','back-button')}<div><h1>桌面设置</h1><p>外观、配色与卡片布局</p></div><span class="autosave-label">${icon('check')}更改自动保存</span></header><nav class="settings-tabs">${[['appearance','外观主题'],['layout','卡片布局'],['motion','切换动效'],['sources','功能接入']].map(([id,t])=>`<button data-action="settings-tab" data-tab="${id}" class="${ui.tab===id?'active':''}">${t}</button>`).join('')}</nav><div class="settings-body ${ui.tab==='appearance'?'appearance-body':''}">${ui.tab==='appearance'?appearanceSettings(theme):ui.tab==='layout'?layoutSettings():ui.tab==='motion'?motionSettings():sourceSettings()}</div></div>${dock()}${modalMarkup(theme)}</div>`;
}
function motionSettings(){return `<section class="settings-block motion-settings"><div class="setting-heading"><h3>桌面翻屏</h3><span>仅桌面卡片切换，底栏保持固定</span></div><div class="motion-options">${[['none','无动画','直接切换，画面不滑动'],['fade','淡入淡出','柔和交替显示'],['slide','横向滑动','跟随翻页方向滑入']].map(([id,name,note])=>`<button data-action="set-transition" data-value="${id}" class="${preferences.pageTransition===id?'selected':''}"><b>${name}</b><p>${note}</p>${preferences.pageTransition===id?icon('check'):'<span class="motion-check"></span>'}</button>`).join('')}</div><p class="motion-note">点击页码或左右轻扫切换桌面。编辑布局时暂停动效；系统要求减少动态效果时使用无动画。</p></section>`;}
function modalMarkup(theme) {
  if(!ui.modal)return '';
  const experience=experienceSheet();if(experience)return experience;
  if(ui.modal==='apps')return `<div class="modal-backdrop"><section class="modal-glass apps-sheet"><header><div><h2>全部应用</h2><p>原车应用入口 · 样式示例</p></div>${actionButton('close-modal','close','关闭全部应用','close-button')}</header><div class="app-drawer">${[['nav','导航','demo-app'],['music','音乐','music-info'],['phone','电话','demo-app'],['car','车辆','vehicle'],['fan','空调','climate'],['camera','全景','camera'],['settings','原车设置','demo-app'],['edit','编辑桌面','start-edit']].map(([i,t,a])=>`<button data-action="${a}"><span>${icon(i)}</span><b>${t}</b></button>`).join('')}</div></section></div>`;
  if(ui.modal==='library')return collectionSheet();
  const c=ui.draft||cards.find(c=>c.id===ui.selected);if(!c)return '';
  const catalog=cardCatalog[c.type];
  const sizes=[c.type==='weather'?[4,2]:[catalog.minW,catalog.minH],[Math.max(4,catalog.minW),Math.max(4,catalog.minH)],[Math.max(8,catalog.minW),6]];
  return `<div class="modal-backdrop"><section class="modal-glass card-config"><header><div><h2>编辑${catalog.name}卡片</h2><p>调整展示，保持官方信息来源</p></div>${actionButton('close-modal','close','关闭卡片设置','close-button')}</header><label class="field-label">${c.type==='weather'?'预览城市（示例）':'卡片名称'}<input name="card-title" value="${safe(c.type==='weather'?(c.city||'杭州'):c.title)}" maxlength="20"></label><div class="field-label">卡片尺寸<div class="size-picker">${sizes.map(([w,h])=>`<button data-action="choose-size" data-w="${w}" data-h="${h}" class="${c.w===w&&c.h===h?'selected':''}"><span class="size-icon" style="aspect-ratio:${w}/${h}"></span><b>${w} × ${h}</b></button>`).join('')}</div></div><div class="config-source"><span>信息来源</span><b>${catalog.source||({clock:'系统时间',shortcuts:'所选原车应用'})[c.type]||'原车应用'}</b></div><div class="modal-actions"><button class="text-button" data-action="close-modal">取消</button><button class="solid-button" data-action="save-card">保存卡片</button></div></section></div>`;
}

function showToast(message,undo=null) {
  ui.toast=message;ui.undo=undo;
  const root=document.getElementById('single-screen');
  root.querySelector('.design-toast')?.remove();
  root.querySelector('.screen')?.insertAdjacentHTML('beforeend',`<div class="design-toast" role="status">${safe(message)}${undo?'<button data-action="undo-delete">撤销</button>':''}</div>`);
  clearTimeout(showToast.timer);
  showToast.timer=setTimeout(()=>{ui.toast='';ui.undo=null;document.querySelector('.design-toast')?.remove();},5000);
}
function updateRadius(value) {
  if(String(value).trim()===''||!Number.isFinite(+value))return;
  preferences.radius=Math.max(0,Math.min(40,Math.round(+value)));
  document.querySelectorAll('.screen').forEach(el=>el.style.setProperty('--card-radius',preferences.radius+'px'));
  document.querySelectorAll('[data-setting="radius"]').forEach(el=>el.value=preferences.radius);
  persistDesign();
}
function renderStandalone() {
  if(designQuery.get('view')==='component'){
    document.getElementById('single-screen').innerHTML=climate(activeTheme());
    resize();return;
  }
  document.body.classList.remove('dock-only','pair','component','cards-only');
  document.body.classList.add('single');
  document.getElementById('single-screen').innerHTML=ui.view==='settings'?settingsScreen(activeTheme()):screen(activeTheme());
  resize();
}
function overlapping(a,b) {return a.page===b.page&&a.x<b.x+b.w&&a.x+a.w>b.x&&a.y<b.y+b.h&&a.y+a.h>b.y;}
function canPlace(candidate,ignore) {return !cards.some(c=>c.id!==ignore&&overlapping(c,candidate));}
function findPlace(w,h,page,ignore) {
  for(let y=0;y<=6-h;y++)for(let x=0;x<=12-w;x++)if(canPlace({x,y,w,h,page},ignore))return{x,y,w,h,page};
  return null;
}
function beginEditing() {ui.snapshot=layoutSnapshot();ui.view='home';ui.editing=true;ui.modal=null;renderStandalone();}
function handleDesignAction(button) {
  const a=button.dataset.action;
  if(a==='home'){if(ui.editing){showToast('请先完成或取消本次布局编辑');return;}ui.view='home';ui.modal=null;renderStandalone();}
  if(a==='open-settings'){if(ui.editing){showToast('请先完成或取消本次布局编辑');return;}ui.view='settings';ui.modal=null;renderStandalone();}
  if(a==='set-transition'){preferences.pageTransition=button.dataset.value;persistDesign();renderStandalone();}
  if(a==='settings-tab'){ui.tab=button.dataset.tab;renderStandalone();}
  if(a==='set-mode'){preferences.mode=button.dataset.value;persistDesign();renderStandalone();}
  if(a==='set-palette'){preferences.palette=button.dataset.value;persistDesign();renderStandalone();}
  if(a==='use-custom'){preferences.palette='custom';persistDesign();renderStandalone();}
  if(a==='toggle-glass'){
    preferences.glass=!preferences.glass;persistDesign();
    document.querySelectorAll('.screen').forEach(el=>{el.style.setProperty('--surface-filter',preferences.glass?'blur(28px) saturate(115%)':'none');el.style.setProperty('--overlay-filter',preferences.glass?'blur(12px)':'none');});
    document.querySelectorAll('[data-action="toggle-glass"]').forEach(el=>el.setAttribute('aria-checked',String(preferences.glass)));
    renderStandalone();
  }
  if(a==='start-edit')beginEditing();
  if(a==='finish-edit'){ui.editing=false;ui.modal=null;persistDesign();renderStandalone();showToast('桌面布局已保存');}
  if(a==='cancel-edit'){restoreSnapshot(ui.snapshot);ui.editing=false;ui.modal=null;renderStandalone();}
  if(a==='open-library'){if(!ui.editing)beginEditing();ui.modal='library';renderStandalone();}
  if(a==='close-modal'){ui.modal=null;renderStandalone();}
  if(a==='add-card'){
    const type=button.dataset.type,c=cardCatalog[type];if(!c)return;
    let place=findPlace(c.w,c.h,ui.page),newPage=false;
    if(!place){ui.page=pageCount++;place=findPlace(c.w,c.h,ui.page);newPage=true;}
    cards.push({id:'card-'+Date.now()+'-'+Math.random().toString(36).slice(2,6),type,title:c.name,city:type==='weather'?'杭州':undefined,forecast:true,...place});
    ui.modal=null;renderStandalone();showToast(newPage?'已添加到新的桌面页':'卡片已添加，可拖动调整位置');
  }
  if(a==='edit-card'){ui.selected=button.dataset.id;ui.draft={...cards.find(c=>c.id===ui.selected)};ui.modal='card';renderStandalone();}
  if(a==='delete-card'){
    const backup=layoutSnapshot();cards=cards.filter(c=>c.id!==button.dataset.id);renderStandalone();showToast('卡片已移除',backup);
  }
  if(a==='undo-delete'){restoreSnapshot(ui.undo);ui.undo=null;ui.toast='';renderStandalone();}
  if(a==='choose-size'){
    const card=ui.draft;if(!card)return;
    const input=document.querySelector('#single-screen [name="card-title"]');
    if(input){if(card.type==='weather')card.city=input.value;else card.title=input.value;}
    if(card.type==='weather'&&document.querySelector('#single-screen [name="weather-forecast"]'))card.forecast=document.querySelector('#single-screen [name="weather-forecast"]').checked;
    const w=+button.dataset.w,h=+button.dataset.h;
    const candidate={...card,w,h};
    const place=card.x+w<=12&&card.y+h<=6&&canPlace(candidate,card.id)?candidate:findPlace(w,h,card.page,card.id);
    if(!place){showToast('此页空间不足，请先缩小或移动其他卡片');return;}
    Object.assign(card,place);renderStandalone();
  }
  if(a==='save-card'){
    const card=cards.find(c=>c.id===ui.selected);if(!card)return;
    Object.assign(card,ui.draft);
    const title=document.querySelector('#single-screen [name="card-title"]').value.trim();
    card.title=title||cardCatalog[card.type].name;
    if(card.type==='weather')card.city=title||'杭州';
    ui.modal=null;renderStandalone();
  }
  if(a==='switch-page'){
    const old=ui.page;ui.page=+button.dataset.page;renderStandalone();
    const grid=document.querySelector('#single-screen .card-grid');
    if(grid&&old!==ui.page&&!ui.editing&&!matchMedia('(prefers-reduced-motion: reduce)').matches){
      if(preferences.pageTransition==='fade')grid.animate([{opacity:0},{opacity:1}],{duration:280,easing:'ease-out'});
      if(preferences.pageTransition==='slide')grid.animate([{transform:`translateX(${ui.page>old?'':'-'}100%)`},{transform:'translateX(0)'}],{duration:280,easing:'ease-out'});
    }
  }
  if(a==='new-page'){ui.page=pageCount++;renderStandalone();}
  if(a==='reset-layout'){cards=defaultCards();pageCount=2;ui.page=0;persistDesign();renderStandalone();showToast('已恢复默认卡片布局');}
  if(a==='toggle-play'){ui.playing=!ui.playing;renderStandalone();}
  if(a==='apps'){if(ui.editing){showToast('请先完成或取消本次布局编辑');return;}ui.modal='apps';renderStandalone();}
  if(a==='demo-app')showToast('设计演示：应用启动将在车机版本接入');
  if(['vehicle','camera','climate','music-info'].includes(a)){ui.modal=a==='music-info'?'music':a;renderStandalone();}
  if(a==='previous'||a==='next'){ui.trackIndex=(ui.trackIndex+1)%demoTracks.length;renderStandalone();}
  if(a==='oem-open'){ui.selectedType=button.dataset.type;ui.modal='oem-open';renderStandalone();}
  if(a==='temp-down'||a==='temp-up'){const zone=button.dataset.zone;ui.climate[zone]=Math.max(16,Math.min(30,ui.climate[zone]+(a==='temp-up'?.5:-.5)));if(ui.climate.sync)ui.climate[zone==='left'?'right':'left']=ui.climate[zone];renderStandalone();}
  if(a==='fan-down'||a==='fan-up'){ui.climate.fan=Math.max(1,Math.min(7,ui.climate.fan+(a==='fan-up'?1:-1)));renderStandalone();}
  if(a==='climate-power'){ui.climate.power=!ui.climate.power;renderStandalone();}
  if(a==='climate-mode'){ui.climate[button.dataset.value]=!ui.climate[button.dataset.value];if(button.dataset.value==='sync'&&ui.climate.sync)ui.climate.right=ui.climate.left;renderStandalone();}
  if(a==='seat-heat'||a==='seat-vent'){
    const zone=button.dataset.zone,value=Number(button.dataset.value);
    if(!['0','1','2','3'].includes(button.dataset.value)||!Number.isInteger(value)||!['left','right'].includes(zone)||(a==='seat-vent'&&zone!=='left'))return;
    const key=a==='seat-vent'?'driverVent':zone==='left'?'driverHeat':'passengerHeat';
    ui.climate[key]=value;
    // Demo policy only; the actual level contract and vehicle behavior need device verification.
    if(value>0&&zone==='left')ui.climate[a==='seat-heat'?'driverVent':'driverHeat']=0;
    document.querySelectorAll('.seat-controls').forEach(el=>el.outerHTML=seatControls());
  }
}
function initCustomization() {
  const view=designQuery.get('view');
  if(['single','settings','edit','library','card-edit','secondary','climate','music','vehicle','camera'].includes(view)){
    ui.view=view==='settings'?'settings':'home';
    if(['edit','library','card-edit'].includes(view)){ui.editing=true;ui.snapshot=layoutSnapshot();}
    if(view==='library')ui.modal='library';
    if(view==='card-edit'){ui.modal='card';ui.selected=cards.find(c=>c.type==='weather')?.id;ui.draft={...cards.find(c=>c.id===ui.selected)};}
    if(view==='secondary')ui.page=Math.min(1,pageCount-1);
    if(['climate','music','vehicle','camera'].includes(view))ui.modal=view;
    renderStandalone();
  }
  if(view==='cards'){document.body.classList.add('cards-only');document.getElementById('single-screen').innerHTML=oemGallery(activeTheme());}
  initHomeHold();
  document.addEventListener('click',e=>{
    const button=e.target.closest('[data-action]');
    if(button){
      if(button.closest('.settings-screen'))ui.view='settings';
      if(button.closest('.board .editing')&&!ui.editing){ui.editing=true;ui.snapshot=layoutSnapshot();}
      handleDesignAction(button);
    }
  });
  document.addEventListener('change',e=>{
    if(e.target.matches('[data-setting="radius"]')){if(e.target.value==='')e.target.value=preferences.radius;updateRadius(e.target.value);return;}
    if(e.target.matches('input[type="color"],.hex-input')){
      const value=e.target.value.trim();
      if(!/^#[0-9a-f]{6}$/i.test(value)){showToast('请输入 # 加六位十六进制色值');return;}
      preferences.custom=value;preferences.palette='custom';persistDesign();renderStandalone();
    }
  });
  document.addEventListener('input',e=>{if(e.target.matches('[data-setting="radius"]'))updateRadius(e.target.value);});
  let holdTimer=null,holdStart=null;
  document.addEventListener('contextmenu',e=>{if(e.target.closest('#single-screen .desktop')&&!ui.editing){e.preventDefault();if(e.target.closest('.widget-card'))beginEditing();else openDesktopSettings();}});
  document.addEventListener('pointerdown',e=>{
    const handle=e.target.closest('#single-screen .card-move, #single-screen .resize-handle');
    if(handle&&ui.editing){
      e.preventDefault();
      const el=handle.closest('.widget-card'),grid=el.closest('.card-grid'),card=cards.find(c=>c.id===el.dataset.card);
      const original={...card},rect=grid.getBoundingClientRect(),sx=rect.width/grid.clientWidth,sy=rect.height/grid.clientHeight;
      const unitX=(grid.clientWidth+24)/12*sx,unitY=(grid.clientHeight+24)/6*sy;
      const startX=e.clientX,startY=e.clientY,resizing=handle.classList.contains('resize-handle');
      let candidate={...card},valid=true;
      const move=event=>{
        const dx=Math.round((event.clientX-startX)/unitX),dy=Math.round((event.clientY-startY)/unitY),cfg=cardCatalog[card.type];
        candidate=resizing?{...original,w:Math.max(cfg.minW,Math.min(12-original.x,original.w+dx)),h:Math.max(cfg.minH,Math.min(6-original.y,original.h+dy))}:{...original,x:Math.max(0,Math.min(12-original.w,original.x+dx)),y:Math.max(0,Math.min(6-original.h,original.y+dy))};
        valid=canPlace(candidate,card.id);
        el.style.gridColumn=`${candidate.x+1}/span ${candidate.w}`;el.style.gridRow=`${candidate.y+1}/span ${candidate.h}`;
        el.classList.toggle('invalid-placement',!valid);el.classList.add('dragging-card');
        el.querySelector('.size-badge').textContent=`${candidate.w} × ${candidate.h}`;
      };
      const up=()=>{
        document.removeEventListener('pointermove',move);document.removeEventListener('pointerup',up);document.removeEventListener('pointercancel',cancel);
        if(valid)Object.assign(card,candidate);renderStandalone();if(!valid)showToast('卡片有重叠，已保留原位置');
      };
      const cancel=()=>{valid=false;up();};
      document.addEventListener('pointermove',move);document.addEventListener('pointerup',up,{once:true});document.addEventListener('pointercancel',cancel,{once:true});
      return;
    }
    if(!ui.editing&&!e.target.closest('button,input')&&e.target.closest('#single-screen .desktop')){
      const onCard=!!e.target.closest('.widget-card');holdStart={x:e.clientX,y:e.clientY};holdTimer=setTimeout(()=>{holdTimer=null;if(onCard)beginEditing();else openDesktopSettings();},650);
    }
  });
  document.addEventListener('pointermove',e=>{if(holdTimer&&holdStart&&Math.hypot(e.clientX-holdStart.x,e.clientY-holdStart.y)>12){clearTimeout(holdTimer);holdTimer=null;}});
  ['pointerup','pointercancel'].forEach(type=>document.addEventListener(type,()=>{clearTimeout(holdTimer);holdTimer=null;}));
  document.addEventListener('keydown',e=>{if(e.key==='Escape'){if(ui.modal){ui.modal=null;renderStandalone();}else if(ui.editing){restoreSnapshot(ui.snapshot);ui.editing=false;ui.page=Math.min(ui.page,pageCount-1);renderStandalone();}else if(ui.view==='settings'){ui.view='home';renderStandalone();}}});
}
