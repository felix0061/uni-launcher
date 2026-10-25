const oemCardDefinitions = {
  calendar:{name:'日历',icon:'calendar',description:'原车日期与日程',source:'原车日历',oem:true,w:4,h:3,minW:3,minH:2},
  member:{name:'账号',icon:'user',description:'原车账号与登录状态',source:'原车账号中心',oem:true,w:4,h:3,minW:3,minH:3},
  cleanup:{name:'系统清理',icon:'broom',description:'原车清理信息与操作',source:'原车安全中心',oem:true,w:4,h:3,minW:3,minH:2},
  tpms:{name:'胎压',icon:'tire',description:'原车四轮胎压信息',source:'原车车辆信息',oem:true,w:4,h:6,minW:4,minH:3},
  battery:{name:'动力电池',icon:'battery',description:'电量、混动与充电状态',source:'原车动力电池',oem:true,w:4,h:3,minW:3,minH:2},
  air:{name:'车内空气',icon:'air',description:'车内 PM2.5 与独立 AQI 读数',source:'原车空气质量',oem:true,w:4,h:3,minW:3,minH:2},
  ride:{name:'出行服务',icon:'ride',description:'其他车型配置中的服务卡片',source:'原车出行服务',oem:true,conditional:true,otherModel:true,w:4,h:3,minW:3,minH:2}
};
const officialCardTypes=['music','nav','weather','calendar','member','cleanup','tpms','battery','air','vehicle','ride'];
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
    case 'tpms':return `${oemHeading(card.title||'胎压','原车车辆信息','tire')}<div class="tpms-visual"><div class="tpms-value front-left"><small>左前</small><b>—</b></div><div class="tpms-value front-right"><small>右前</small><b>—</b></div><svg class="tpms-car" viewBox="0 0 150 260" aria-hidden="true"><rect x="34" y="12" width="82" height="236" rx="33"/><path d="M42 74q33-17 66 0l-7 39H49ZM49 177h52l7 34q-33 13-66 0ZM47 115v59m56-59v59"/><path class="tires" d="M28 58v34m94-34v34M28 173v34m94-34v34"/></svg><div class="tpms-value rear-left"><small>左后</small><b>—</b></div><div class="tpms-value rear-right"><small>右后</small><b>—</b></div></div><div class="oem-state-line"><i></i>等待车辆数据</div>`;
    case 'battery':case 'air':case 'vehicle':return vehicleCardBody(card);
    case 'ride':return `${oemHeading(card.title||'出行服务','原车出行服务','ride')}<div class="ride-summary">${icon('ride')}<h3>出行服务</h3><p>服务信息未同步</p></div><div class="oem-state-line">其他车型配置 · 本车未确认</div>`;
    default:return '';
  }
}
// Fixed examples are opt-in review content. Desktop cards start disconnected.
function vehicleExampleReading(card,key) {
  const examples={batteryPercent:[95,'%'],pm25:[12,'µg/m³'],aqi:[28,''],speed:[62.5,'km/h'],odometer:[18764,'km'],range:[426,'km'],maintenanceMileage:[3200,'km']};
  const state=card.reviewState||'live';
  if(!card.example||state==='disconnected')return {value:'—',unit:'',status:'未连接',live:false};
  if(state==='partial') {
    if(['batteryPercent','speed'].includes(key))return {value:'—',unit:'',status:'等待更新',live:false};
    if(['aqi','maintenanceMileage'].includes(key))return {value:'—',unit:'',status:'暂无数据',live:false};
    if(key==='range')return {value:'—',unit:'',status:'单位待确认',live:false};
  }
  return {value:examples[key][0],unit:examples[key][1],status:'已同步',live:true};
}
function vehicleCardBody(card) {
  const read=key=>vehicleExampleReading(card,key);
  const value=(r,unit=r.unit)=>`<div class="vehicle-reading ${r.live?'is-live':''}"><b>${safe(r.value)}</b>${unit?`<small>${safe(unit)}</small>`:''}</div>`;
  const footer=(label,status)=>`<div class="vehicle-reading-state"><span>${safe(label)}</span><span>${safe(status)}</span></div>`;
  if(card.type==='battery'){
    const r=read('batteryPercent');
    return `${oemHeading(card.title||'动力电池','电量','battery')}<div class="battery-main">${value(r,'%')}</div><div class="battery-level" aria-hidden="true"><i style="width:${r.live?r.value:0}%"></i></div>${footer('剩余电量',r.status)}<div class="vehicle-divider"></div>${footer('驾驶模式',card.example&&card.reviewState!=='disconnected'?(card.reviewState==='partial'?'等待更新':'混动'):'未连接')}<div class="power-state-gap"></div>${footer('能量流',card.example&&card.reviewState!=='disconnected'?(card.reviewState==='partial'?'待同步':'电力驱动'):'未连接')}<div class="power-state-gap"></div>${footer('外接充电','待同步')}`;
  }
  if(card.type==='air'){
    const pm=read('pm25'),aqi=read('aqi');
    const title=!card.title||card.title==='空气质量'?'车内空气':card.title;
    return `${oemHeading(title,'车内','air')}<div class="air-pm-label">PM2.5</div><div class="air-pm-main">${value(pm,'µg/m³')}</div>${footer('PM2.5',pm.status)}<div class="vehicle-divider"></div><div class="air-aqi"><span>车内 AQI</span>${value(aqi)}<small>${safe(aqi.status)}</small></div>`;
  }
  const title=!card.title||['车辆信息','行驶信息'].includes(card.title)?'行车信息':card.title;
  return `${oemHeading(title,'原车','car')}<div class="driving-metrics">${[['speed','车速'],['odometer','总里程'],['range','续航'],['maintenanceMileage','距保养']].map(([key,label])=>{const r=read(key);return `<div class="driving-metric ${key==='speed'?'speed-metric':''}"><span>${label}</span>${value(r)}<small>${safe(r.status)}</small></div>`;}).join('')}</div>`;
}
function vehicleGallery(theme) {
  const requested=designQuery.get('state');
  const state=['live','partial','disconnected'].includes(requested)?requested:'live';
  const label={live:'有效读数',partial:'独立字段状态',disconnected:'断连'}[state];
  const row=compact=>`<div class="vehicle-gallery-row ${compact?'minimum':''}">${['battery','air','vehicle'].map(type=>widget({id:'vehicle-gallery-'+type+(compact?'-min':''),type,title:cardCatalog[type].name,example:true,reviewState:state,x:0,y:0,w:compact?3:4,h:compact?2:3,page:0},false)).join('')}</div>`;
  return `<div class="screen glass ${theme} vehicle-gallery" style="${themeStyle(theme)}"><header><span>LYNK & CO / 05 · 车辆卡片</span><div><h1>车辆信息，一眼可读。</h1><p>${theme==='dark'?'深色':'浅色'} · ${label} · 圆角 ${preferences.radius} · ${preferences.glass?'毛玻璃':'半透明'}</p></div><p>示例数据 · 仅供样式评审，不代表车辆当前读数</p></header><h2>常规 / 4 × 3</h2>${row(false)}<h2>紧凑 / 最小 3 × 2</h2>${row(true)}<footer>模式与能量流独立读取 · 不推断外接充电与纯电续航 · 速度和距离保留已确认的单位</footer></div>`;
}
function oemGallery(theme) {
  const demos=officialCardTypes.map(type=>({id:'gallery-'+type,type,title:cardCatalog[type].name,example:true,city:'杭州',forecast:false,x:0,y:0,w:4,h:3,page:0}));
  return `<div class="screen glass ${theme} oem-gallery" style="${themeStyle(theme)}"><header class="oem-gallery-header"><div><span>LYNK 05 / OEM CARD COLLECTION</span><h1>原车信息，新的表达。</h1><p>保留默认桌面 · 动力电池、车内空气与行车信息可单独添加</p></div><span class="gallery-demo">样式示例 · 非车辆当前读数</span></header><div class="oem-gallery-grid">${demos.map(c=>widget(c,false)).join('')}</div></div>`;
}
function collectionSheet() {
  const entries=Object.entries(cardCatalog).filter(([k,c])=>!c.otherModel);
  const official=entries.filter(([k,c])=>c.oem),extras=entries.filter(([k,c])=>!c.oem);
  const tiles=items=>items.map(([type,c])=>`<button class="library-item" data-action="add-card" data-type="${type}"><div class="library-preview ${type}"><span>${icon(c.icon)}</span><i></i><i></i></div><div class="library-copy"><strong>${c.name}${c.conditional?'<em>按车型</em>':''}</strong><small>${c.description}</small><span>${icon('plus')}</span></div></button>`).join('');
  return `<div class="modal-backdrop"><section class="modal-glass library-sheet"><header><div><h2>添加卡片</h2><p>原车卡片使用官方信息来源，统一为桌面样式</p></div>${actionButton('close-modal','close','关闭卡片库','close-button')}</header><div class="library-scroll"><h3>原车卡片</h3><div class="card-library">${tiles(official)}</div><h3>桌面扩展</h3><div class="card-library">${tiles(extras)}</div></div><footer>可重复添加 · 空间不足时添加到新页 · 其他车型卡片见样式总览</footer></section></div>`;
}
function seatControls() {
  const seats=[['driverHeat','seat-heat','left','主驾座椅加热'],['driverVent','seat-vent','left','主驾通风'],['passengerHeat','seat-heat','right','副驾加热']];
  return `<section class="seat-controls" aria-label="座椅舒适"><div class="seat-heading"><h3>座椅舒适</h3><span>主驾加热 / 通风互斥</span></div>${seats.map(([key,action,zone,label])=>`<div class="seat-row" data-seat="${key}"><div class="seat-label">${icon(action)}<span>${label}</span></div><div class="seat-levels" role="group" aria-label="${label}">${[0,1,2,3].map(value=>`<button data-action="${action}" data-zone="${zone}" data-value="${value}" class="${ui.climate[key]===value?'selected':''}" aria-pressed="${ui.climate[key]===value}" aria-label="${label} ${value===0?'关闭':value+'档'}">${value===0?'关闭':value+'档'}</button>`).join('')}</div></div>`).join('')}<p class="seat-note">示例档位 · 实际档位契约待实车确认</p></section>`;
}
function experienceSheet() {
  const header=(title,sub)=>`<header><div><h2>${title}</h2><p>${sub}</p></div>${actionButton('close-modal','close','关闭面板','close-button')}</header>`;
  if(ui.modal==='climate')return `<div class="modal-backdrop"><section class="modal-glass climate-sheet">${header('座舱舒适','操作预览 · 未连接车辆')}<div class="climate-sheet-zones">${['left','right'].map((zone,i)=>`<div><span>${i?'副驾':'主驾'}</span><div>${actionButton('temp-down','minus','降低'+(i?'副驾':'主驾')+'温度','climate-step',`data-zone="${zone}"`)}<b>${temperature(zone)}<sup>°</sup></b>${actionButton('temp-up','plus','升高'+(i?'副驾':'主驾')+'温度','climate-step',`data-zone="${zone}"`)}</div></div>`).join('')}</div><div class="climate-sheet-fan">${icon('fan')}<span>风量</span>${actionButton('fan-down','minus','降低风量','climate-step')}<b>${ui.climate.fan}</b>${actionButton('fan-up','plus','提高风量','climate-step')}</div><div class="climate-sheet-modes">${[['auto','AUTO'],['ac','A/C'],['sync','双区同步'],['recirc','内循环']].map(([id,t])=>`<button class="${ui.climate[id]?'selected':''}" data-action="climate-mode" data-value="${id}">${t}</button>`).join('')}</div>${seatControls()}</section></div>`;
  if(ui.modal==='music'){const m=mediaState();return `<div class="modal-backdrop"><section class="modal-glass music-sheet">${header('正在播放','原车媒体中心 · 样式示例')}<div class="music-detail"><div class="cover hero-cover">${art}</div><div><h3>${m.title}</h3><p>${m.artist} · ${m.collection}</p><div class="lyrics-preview"><div>晨光沿着海岸慢慢亮起</div><div class="current">风把远方带进了呼吸</div><div>穿过山与海的交界</div></div><div class="music-progress"><div class="track-line"></div><div class="music-times"><span>00:04</span><span>04:18</span></div></div><div class="dock-transport">${actionButton('previous','back','上一首','dock-control')}${actionButton('toggle-play',ui.playing?'pause':'play',ui.playing?'暂停':'播放','dock-play')}${actionButton('next','next','下一首','dock-control')}</div></div></div></section></div>`;}
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
