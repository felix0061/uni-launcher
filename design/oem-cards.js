const oemCardDefinitions = {
  calendar:{name:'日历',icon:'calendar',description:'原车日期与日程',source:'原车日历',oem:true,w:4,h:3,minW:3,minH:2},
  member:{name:'账号',icon:'user',description:'原车账号与登录状态',source:'原车账号中心',oem:true,w:4,h:3,minW:3,minH:3},
  cleanup:{name:'系统清理',icon:'broom',description:'原车清理信息与操作',source:'原车安全中心',oem:true,w:4,h:3,minW:3,minH:2},
  tpms:{name:'胎压',icon:'tire',description:'原车四轮胎压信息',source:'原车车辆信息',oem:true,w:4,h:6,minW:4,minH:3},
  air:{name:'空气质量',icon:'air',description:'原车空气质量 · 按车型支持',source:'原车空气质量',oem:true,conditional:true,w:4,h:3,minW:3,minH:2},
  ride:{name:'出行服务',icon:'ride',description:'其他车型配置中的服务卡片',source:'原车出行服务',oem:true,conditional:true,otherModel:true,w:4,h:3,minW:3,minH:2}
};
const officialCardTypes=['music','nav','weather','calendar','member','cleanup','tpms','air','ride'];
const demoTracks=[
  {title:'向海而行',artist:'Coastline',collection:'晨间驾驶歌单'},
  {title:'山海之间',artist:'Northbound',collection:'沿途风景歌单'}
];
function mediaState(){return demoTracks[ui.trackIndex||0];}
function temperature(zone){return (ui.climate[zone]||22.5).toFixed(1);}
function oemHeading(title,source,symbol){return `<div class="oem-card-heading"><span>${icon(symbol)}${safe(title)}</span><small>${safe(source)}</small></div>`;}
function oemCardBody(card) {
  switch(card.type){
    case 'calendar':return `${oemHeading(card.title||'日历','原车日历','calendar')}<div class="calendar-date"><b>24</b><div><span>星期六</span><small>2026 年 10 月</small></div></div><div class="calendar-agenda"><i></i><div><strong>日程未同步</strong><span>连接后显示原车日程</span></div></div>`;
    case 'member':return `${oemHeading(card.title||'领克账号','账号中心','user')}<div class="member-profile"><span class="member-avatar">${icon('user')}</span><h3>领克账号</h3><p>账号状态未同步</p></div><button class="outline-button oem-open" data-action="oem-open" data-type="member">${icon('arrow-right')}打开账号中心</button>`;
    case 'cleanup':return `${oemHeading(card.title||'系统清理','原车安全中心','broom')}<div class="cleanup-summary"><span>${icon('broom')}</span><div><b>—</b><p>清理状态未同步</p></div></div><button class="outline-button oem-open" data-action="oem-open" data-type="cleanup">打开原车清理${icon('arrow-right')}</button>`;
    case 'tpms':case 'vehicle':return `${oemHeading(card.type==='vehicle'?'车辆信息':(card.title||'胎压'),'原车车辆信息','tire')}<div class="tpms-visual"><div class="tpms-value front-left"><small>左前</small><b>—</b></div><div class="tpms-value front-right"><small>右前</small><b>—</b></div><svg class="tpms-car" viewBox="0 0 150 260" aria-hidden="true"><rect x="34" y="12" width="82" height="236" rx="33"/><path d="M42 74q33-17 66 0l-7 39H49ZM49 177h52l7 34q-33 13-66 0ZM47 115v59m56-59v59"/><path class="tires" d="M28 58v34m94-34v34M28 173v34m94-34v34"/></svg><div class="tpms-value rear-left"><small>左后</small><b>—</b></div><div class="tpms-value rear-right"><small>右后</small><b>—</b></div></div><div class="oem-state-line"><i></i>等待车辆数据</div>`;
    case 'air':return `${oemHeading(card.title||'空气质量','原车空气质量','air')}<div class="air-summary">${icon('air')}<b>—</b><span>空气质量未同步</span></div><div class="oem-state-line">按车辆空气质量功能支持情况启用</div>`;
    case 'ride':return `${oemHeading(card.title||'出行服务','原车出行服务','ride')}<div class="ride-summary">${icon('ride')}<h3>出行服务</h3><p>服务信息未同步</p></div><div class="oem-state-line">其他车型配置 · 本车未确认</div>`;
    default:return '';
  }
}
function oemGallery(theme) {
  const demos=officialCardTypes.map(type=>({id:'gallery-'+type,type,title:cardCatalog[type].name,city:'杭州',forecast:false,x:0,y:0,w:4,h:3,page:0}));
  return `<div class="screen glass ${theme} oem-gallery" style="${themeStyle(theme)}"><header class="oem-gallery-header"><div><span>LYNK 05 / OEM CARD COLLECTION</span><h1>原车信息，新的表达。</h1><p>七类 IP753 默认卡片 + 空气质量与出行服务的车型可选样式</p></div><span class="gallery-demo">样式示例 · 数据字段待核对</span></header><div class="oem-gallery-grid">${demos.map(c=>widget(c,false)).join('')}</div></div>`;
}
function collectionSheet() {
  const entries=Object.entries(cardCatalog).filter(([k,c])=>!c.otherModel);
  const official=entries.filter(([k,c])=>c.oem),extras=entries.filter(([k,c])=>!c.oem);
  const tiles=items=>items.map(([type,c])=>`<button class="library-item" data-action="add-card" data-type="${type}"><div class="library-preview ${type}"><span>${icon(c.icon)}</span><i></i><i></i></div><div class="library-copy"><strong>${c.name}${c.conditional?'<em>按车型</em>':''}</strong><small>${c.description}</small><span>${icon('plus')}</span></div></button>`).join('');
  return `<div class="modal-backdrop"><section class="modal-glass library-sheet"><header><div><h2>添加卡片</h2><p>原车卡片使用官方信息来源，统一为桌面样式</p></div>${actionButton('close-modal','close','关闭卡片库','close-button')}</header><div class="library-scroll"><h3>原车卡片</h3><div class="card-library">${tiles(official)}</div><h3>桌面扩展</h3><div class="card-library">${tiles(extras)}</div></div><footer>可重复添加 · 空间不足时添加到新页 · 其他车型卡片见样式总览</footer></section></div>`;
}
function experienceSheet() {
  const header=(title,sub)=>`<header><div><h2>${title}</h2><p>${sub}</p></div>${actionButton('close-modal','close','关闭面板','close-button')}</header>`;
  if(ui.modal==='climate')return `<div class="modal-backdrop"><section class="modal-glass climate-sheet">${header('座舱舒适','操作预览 · 未连接车辆')}<div class="climate-sheet-zones">${['left','right'].map((zone,i)=>`<div><span>${i?'副驾':'主驾'}</span><div>${actionButton('temp-down','minus','降低'+(i?'副驾':'主驾')+'温度','climate-step',`data-zone="${zone}"`)}<b>${temperature(zone)}<sup>°</sup></b>${actionButton('temp-up','plus','升高'+(i?'副驾':'主驾')+'温度','climate-step',`data-zone="${zone}"`)}</div></div>`).join('')}</div><div class="climate-sheet-fan">${icon('fan')}<span>风量</span>${actionButton('fan-down','minus','降低风量','climate-step')}<b>${ui.climate.fan}</b>${actionButton('fan-up','plus','提高风量','climate-step')}</div><div class="climate-sheet-modes">${[['auto','AUTO'],['ac','A/C'],['sync','双区同步'],['recirc','内循环']].map(([id,t])=>`<button class="${ui.climate[id]?'selected':''}" data-action="climate-mode" data-value="${id}">${t}</button>`).join('')}</div></section></div>`;
  if(ui.modal==='music'){const m=mediaState();return `<div class="modal-backdrop"><section class="modal-glass music-sheet">${header('正在播放','原车媒体中心 · 样式示例')}<div class="music-detail"><div class="cover hero-cover">${art}</div><div><h3>${m.title}</h3><p>${m.artist} · ${m.collection}</p><div class="dock-transport">${actionButton('previous','back','上一首','dock-control')}${actionButton('toggle-play',ui.playing?'pause':'play',ui.playing?'暂停':'播放','dock-play')}${actionButton('next','next','下一首','dock-control')}</div></div></div></section></div>`;}
  if(ui.modal==='vehicle')return `<div class="modal-backdrop"><section class="modal-glass vehicle-sheet">${header('车辆信息','原车车辆信息 · 等待连接')}<div class="vehicle-panel-body">${oemCardBody({type:'tpms',title:'四轮胎压'})}</div></section></div>`;
  if(ui.modal==='camera')return `<div class="modal-backdrop"><section class="modal-glass camera-sheet">${header('360 影像','原车全景影像入口')}<div class="camera-placeholder">${icon('camera')}<h3>等待车辆影像</h3><p>车辆连接后，由原车影像服务提供画面</p></div></section></div>`;
  if(ui.modal==='oem-open'){const c=cardCatalog[ui.selectedType];return `<div class="modal-backdrop"><section class="modal-glass source-sheet">${header(c?.source||'原车应用','应用入口样式预览')}<div class="source-placeholder">${icon(c?.icon||'apps')}<h3>等待原车服务</h3><p>正式车机版本打开对应的原车应用</p></div></section></div>`;}
  return '';
}
function openDesktopSettings() {
  if(ui.editing){showToast('请先完成或取消本次布局编辑');return;}
  ui.view='settings';ui.modal=null;renderStandalone();
}
function layoutSnapshot(){return JSON.stringify({cards,pageCount});}
function restoreSnapshot(snapshot){
  if(!snapshot)return;
  const data=JSON.parse(snapshot);
  cards=Array.isArray(data)?data:data.cards;
  pageCount=Array.isArray(data)?Math.max(1,...cards.map(c=>c.page+1)):data.pageCount;
  ui.page=Math.min(ui.page,pageCount-1);
}
function initHomeHold(){
  let timer=null,origin=null,suppressUntil=0;
  const home=target=>target.closest('[data-home-hold]');
  const clear=()=>{clearTimeout(timer);timer=null;};
  const start=()=>{clear();timer=setTimeout(()=>{suppressUntil=Date.now()+900;openDesktopSettings();},650);};
  document.addEventListener('pointerdown',e=>{if(!home(e.target)||e.button!==0)return;origin={x:e.clientX,y:e.clientY};start();});
  document.addEventListener('pointermove',e=>{if(timer&&origin&&Math.hypot(e.clientX-origin.x,e.clientY-origin.y)>12)clear();});
  ['pointerup','pointercancel','blur'].forEach(name=>window.addEventListener(name,clear,true));
  document.addEventListener('click',e=>{if(home(e.target)&&Date.now()<suppressUntil){e.preventDefault();e.stopImmediatePropagation();}},true);
  document.addEventListener('contextmenu',e=>{if(home(e.target)){e.preventDefault();clear();suppressUntil=Date.now()+900;openDesktopSettings();}});
  document.addEventListener('keydown',e=>{if(!home(e.target))return;if((e.key===' '||e.key==='Enter')&&!e.repeat)start();if(e.key==='ContextMenu'||(e.shiftKey&&e.key==='F10')){e.preventDefault();openDesktopSettings();}});
  document.addEventListener('keyup',clear);
}
