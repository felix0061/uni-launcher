#!/usr/bin/env node
// Local-only design renderer. Uses a disposable Chrome profile, never a user profile.
import {spawn} from 'node:child_process';
import {mkdtemp, readFile, writeFile, rm} from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {fileURLToPath, pathToFileURL} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const profile=await mkdtemp(path.join(os.tmpdir(),'lynk-design-review-'));
const chrome=spawn(process.env.LYNK_REVIEW_CHROME||'google-chrome',['--headless=new','--disable-gpu','--disable-background-networking','--disable-component-update','--disable-sync','--disable-extensions','--no-first-run','--no-default-browser-check','--hide-scrollbars','--remote-debugging-address=127.0.0.1','--remote-debugging-port=0','--log-level=3','--user-data-dir='+profile,'about:blank'],{stdio:['ignore','ignore','pipe']});
let stderr='';chrome.stderr.on('data',d=>{stderr+=d;});
const delay=ms=>new Promise(r=>setTimeout(r,ms));
let ws,seq=0;const pending=new Map();const errors=[];
try {
  let port;
  for(let i=0;i<120;i++){
    try{port=(await readFile(path.join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];break;}catch{}
    if(chrome.exitCode!==null)throw Error('Chrome exited: '+stderr.slice(-1500));
    await delay(100);
  }
  if(!port)throw Error('Chrome did not expose its local review endpoint');
  const tab=await (await fetch(`http://127.0.0.1:${port}/json/new?about:blank`,{method:'PUT'})).json();
  ws=new WebSocket(tab.webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{ws.addEventListener('open',resolve,{once:true});ws.addEventListener('error',reject,{once:true});});
  ws.addEventListener('message',event=>{
    const m=JSON.parse(event.data);
    if(m.id){const p=pending.get(m.id);if(p){pending.delete(m.id);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result);}}
    if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails.text+': '+(m.params.exceptionDetails.exception?.description||''));
  });
  const send=(method,params={})=>new Promise((resolve,reject)=>{const id=++seq;pending.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}));});
  const evaluate=async expression=>{
    const r=await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true,userGesture:true});
    if(r.exceptionDetails)throw Error(r.exceptionDetails.exception?.description||r.exceptionDetails.text);
    return r.result.value;
  };
  await send('Page.enable');await send('Runtime.enable');
  const navigate=async(view,theme='dark',width=1920,height=1080,extra={})=>{
    await send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
    const u=pathToFileURL(path.join(root,'design/index.html'));
    u.search=new URLSearchParams({view,theme,export:'1',rev:'v04-seat-comfort',...extra}).toString();
    await send('Page.navigate',{url:u.href});
    for(let i=0;i<120;i++){
      if(await evaluate(`location.href===${JSON.stringify(u.href)}&&document.readyState==='complete'`))break;
      await delay(50);
    }
    await evaluate(`(async()=>{await document.fonts.ready;await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));return true})()`);
  };
  const click=selector=>evaluate(`document.querySelector('#single-screen '+${JSON.stringify(selector)}).click();true`);
  const results=[];
  const check=(name,pass)=>{results.push({name,passed:!!pass});if(!pass)throw Error('Design check failed: '+name);};
  await navigate('single');
  check('seven default OEM cards',await evaluate(`cards.length===7&&['music','nav','weather','calendar','member','cleanup','tpms'].every(t=>cards.some(c=>c.type===t))`));
  check('dock group order',await evaluate(`JSON.stringify([...document.querySelectorAll('#single-screen [data-dock-group]')].map(x=>x.dataset.dockGroup))===JSON.stringify(['navigation','climate','transport','info','vehicle','camera'])`));
  check('no desktop settings icon',await evaluate(`!document.querySelector('#single-screen [data-action="open-settings"]')`));
  check('home tap',await evaluate(`document.querySelector('#single-screen [data-action="home"]').click();ui.view==='home'`));
  const rect=await evaluate(`(()=>{const r=document.querySelector('#single-screen [data-home-hold]').getBoundingClientRect();return{x:r.x+r.width/2,y:r.y+r.height/2}})()`);
  await send('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',buttons:1,clickCount:1,...rect});
  await delay(750);
  await send('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',buttons:0,clickCount:1,...rect});
  check('home long press opens settings',await evaluate(`ui.view==='settings'`));
  await navigate('single');
  const gap=await evaluate(`(()=>{const r=document.querySelector('#single-screen .nav-card').getBoundingClientRect();return{x:r.right+12,y:r.y+200}})()`);
  await send('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',buttons:1,clickCount:1,...gap});await delay(750);
  await send('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',buttons:0,clickCount:1,...gap});
  check('home background long press opens settings',await evaluate(`ui.view==='settings'`));
  await navigate('single');
  const cardPoint=await evaluate(`(()=>{const r=document.querySelector('#single-screen .nav-card').getBoundingClientRect();return{x:r.x+180,y:r.y+330}})()`);
  await send('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',buttons:1,clickCount:1,...cardPoint});await delay(750);
  await send('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',buttons:0,clickCount:1,...cardPoint});
  check('card long press enters layout editing',await evaluate(`ui.editing&&ui.view==='home'`));
  await click('[data-action="cancel-edit"]');
  await navigate('settings');
  check('glass defaults off in preview sidebar',await evaluate(`preferences.glass===false&&document.querySelector('#single-screen .settings-preview [data-action="toggle-glass"]').getAttribute('aria-checked')==='false'`));
  const surfaceColors=await evaluate(`[...document.querySelectorAll('#single-screen .settings-preview,#single-screen .mini-screen-wrap .music-dock')].map(el=>getComputedStyle(el).backgroundColor)`);
  const checkGlass=async enabled=>check('glass '+(enabled?'on':'off')+' synchronizes preview and surfaces',await evaluate(`(()=>{
    const surfaces=[...document.querySelectorAll('#single-screen .settings-block,#single-screen .settings-preview,#single-screen .mini-screen-wrap .widget-card,#single-screen .music-dock')];
    return preferences.glass===${enabled}&&document.querySelector('#single-screen [data-action="toggle-glass"]').getAttribute('aria-checked')==='${enabled}'&&surfaces.every(el=>${enabled?"getComputedStyle(el).backdropFilter.includes('blur(28px)')":"getComputedStyle(el).backdropFilter==='none'"})&&[...document.querySelectorAll('.screen')].every(el=>getComputedStyle(el).getPropertyValue('--surface-filter').trim()===${JSON.stringify(enabled?'blur(28px) saturate(115%)':'none')});
  })()`));
  await checkGlass(false);
  await click('[data-action="toggle-glass"]');await checkGlass(true);
  await click('[data-action="climate"]');
  check('glass enabled on climate overlay',await evaluate(`getComputedStyle(document.querySelector('#single-screen .modal-backdrop')).backdropFilter==='blur(12px)'&&getComputedStyle(document.querySelector('#single-screen .climate-sheet')).backdropFilter.includes('blur(28px)')`));
  await click('[data-action="close-modal"]');
  await click('[data-action="toggle-glass"]');await checkGlass(false);
  check('glass off preserves translucent colors',await evaluate(`(()=>{
    const surfaces=[...document.querySelectorAll('#single-screen .settings-preview,#single-screen .mini-screen-wrap .music-dock')];
    return JSON.stringify(surfaces.map(el=>getComputedStyle(el).backgroundColor))===${JSON.stringify(JSON.stringify(surfaceColors))}&&surfaces.every(el=>{const color=getComputedStyle(el).backgroundColor;const alpha=Number(color.match(/,\\s*([\\d.]+)\\)$/)?.[1]);return color.startsWith('rgba(')&&alpha>0&&alpha<1;});
  })()`));
  for(const value of [0,40,28]){
    await evaluate(`(()=>{const el=document.querySelector('#single-screen [data-setting="radius"]');el.value=${value};el.dispatchEvent(new Event('input',{bubbles:true}));})()`);
    check('radius '+value,await evaluate(`preferences.radius===${value}&&getComputedStyle(document.querySelector('#single-screen .settings-block')).borderTopLeftRadius==='${value}px'`));
  }
  await click('[data-action="settings-tab"][data-tab="motion"]');
  check('page transition settings offers none fade slide',await evaluate(`document.querySelectorAll('#single-screen [data-action="set-transition"]').length===3&&preferences.pageTransition==='none'`));
  await click('[data-action="set-transition"][data-value="slide"]');
  check('page transition selection persists in prototype',await evaluate(`preferences.pageTransition==='slide'`));
  await click('[data-action="settings-tab"][data-tab="appearance"]');
  await click('[data-action="set-palette"][data-value="blue"]');
  check('theme preview synchronizes',await evaluate(`getComputedStyle(document.querySelector('#single-screen>.screen')).getPropertyValue('--accent')===getComputedStyle(document.querySelector('#single-screen .mini-screen-wrap>.screen')).getPropertyValue('--accent')`));
  await click('[data-action="set-palette"][data-value="mint"]');
  await evaluate(`(()=>{const el=document.querySelector('#single-screen .hex-input');el.value='#9955AA';el.dispatchEvent(new Event('change',{bubbles:true}));})()`);
  check('custom color',await evaluate(`preferences.palette==='custom'&&preferences.custom==='#9955AA'`));
  await click('[data-action="set-palette"][data-value="mint"]');
  await click('[data-action="home"]');
  await click('[data-action="temp-up"][data-zone="left"]');
  await click('[data-action="climate"]');
  check('climate dock and panel share state',await evaluate(`ui.modal==='climate'&&temperature('left')==='23.0'&&document.querySelector('#single-screen .climate-sheet').innerText.includes('23.0')`));
  check('glass off removes climate overlay blur',await evaluate(`getComputedStyle(document.querySelector('#single-screen .modal-backdrop')).backdropFilter==='none'&&getComputedStyle(document.querySelector('#single-screen .climate-sheet')).backdropFilter==='none'`));
  const seatSpecs=[['driverHeat','seat-heat','left'],['driverVent','seat-vent','left'],['passengerHeat','seat-heat','right']];
  const seatSelector=(action,zone,value)=>`[data-action="${action}"][data-zone="${zone}"][data-value="${value}"]`;
  const seatStateMatches=()=>evaluate(`[...document.querySelectorAll('.seat-row')].every(row=>{const buttons=[...row.querySelectorAll('button')];return buttons.length===4&&buttons.every(b=>b.classList.contains('selected')===(Number(b.dataset.value)===ui.climate[row.dataset.seat])&&b.getAttribute('aria-pressed')===String(Number(b.dataset.value)===ui.climate[row.dataset.seat]));})`);
  check('seat controls expose explicit off and three levels',await evaluate(`document.querySelectorAll('#single-screen .seat-row').length===3&&[...document.querySelectorAll('#single-screen .seat-levels')].every(group=>JSON.stringify([...group.children].map(b=>b.textContent))===JSON.stringify(['关闭','1档','2档','3档']))`));
  check('seats default off',await evaluate(`ui.climate.driverHeat===0&&ui.climate.driverVent===0&&ui.climate.passengerHeat===0`)&&await seatStateMatches());
  for(const [key,action,zone] of seatSpecs){
    for(const value of [1,2,3,3,0]){
      await click(seatSelector(action,zone,value));
      check(key+' explicit level '+value,await evaluate(`ui.climate.${key}===${value}`)&&await seatStateMatches());
    }
  }
  await click(seatSelector('seat-heat','right',2));
  await click(seatSelector('seat-heat','left',3));await click(seatSelector('seat-vent','left',2));
  check('driver ventilation clears heating only',await evaluate(`ui.climate.driverHeat===0&&ui.climate.driverVent===2&&ui.climate.passengerHeat===2`)&&await seatStateMatches());
  await click(seatSelector('seat-heat','left',1));
  check('driver heating clears ventilation only',await evaluate(`ui.climate.driverHeat===1&&ui.climate.driverVent===0&&ui.climate.passengerHeat===2`)&&await seatStateMatches());
  await click(seatSelector('seat-vent','left',0));
  check('turning ventilation off preserves heating',await evaluate(`ui.climate.driverHeat===1&&ui.climate.driverVent===0`));
  await click(seatSelector('seat-vent','left',3));await click(seatSelector('seat-heat','left',0));
  check('turning heating off preserves ventilation',await evaluate(`ui.climate.driverHeat===0&&ui.climate.driverVent===3`));
  check('no passenger ventilation control or state',await evaluate(`!document.querySelector('[data-action="seat-vent"][data-zone="right"]')&&!('passengerVent' in ui.climate)`));
  check('unsupported seat zone and level are ignored',await evaluate(`(()=>{const before=JSON.stringify(ui.climate);for(const dataset of [{action:'seat-vent',zone:'right',value:'2'},{action:'seat-heat',zone:'left',value:'4'},{action:'seat-heat',zone:'left',value:'-1'},{action:'seat-heat',zone:'left',value:''},{action:'seat-heat',zone:'right',value:'1.5'}])handleDesignAction({dataset});return before===JSON.stringify(ui.climate);})()`));
  await click('[data-action="close-modal"]');await click('[data-action="climate"]');
  check('seat selections survive panel reopening',await evaluate(`ui.climate.driverVent===3&&ui.climate.passengerHeat===2`)&&await seatStateMatches());
  for(const radius of [0,40,28]){
    await evaluate(`updateRadius(${radius});true`);
    check('seat level radius '+radius,await evaluate(`Math.abs(parseFloat(getComputedStyle(document.querySelector('#single-screen .seat-levels button')).borderTopLeftRadius)-${radius}*.64)<.01`));
  }
  for(const [,action,zone] of seatSpecs)await click(seatSelector(action,zone,0));
  check('all seats explicitly off',await evaluate(`ui.climate.driverHeat===0&&ui.climate.driverVent===0&&ui.climate.passengerHeat===0`)&&await seatStateMatches());
  await click('[data-action="close-modal"]');
  await click('[data-action="next"]');
  await click('[data-action="music-info"]');
  check('media information shares state',await evaluate(`ui.modal==='music'&&mediaState().title==='山海之间'&&document.querySelector('#single-screen .music-detail').innerText.includes('山海之间')`));
  await click('[data-action="close-modal"]');
  for(const view of ['vehicle','camera']){await click('[data-action="'+view+'"]');check(view+' panel',await evaluate(`ui.modal===${JSON.stringify(view)}&&!!document.querySelector('#single-screen .${view}-sheet')`));await click('[data-action="close-modal"]');}
  await evaluate(`beginEditing();true`);
  await click('[data-action="delete-card"][data-id="weather-1"]');
  check('delete card',await evaluate(`!cards.some(c=>c.id==='weather-1')`));
  await click('[data-action="undo-delete"]');
  check('undo deletion',await evaluate(`cards.some(c=>c.id==='weather-1')`));
  await click('[data-action="edit-card"][data-id="weather-1"]');
  await evaluate(`document.querySelector('#single-screen [name="card-title"]').value='南京';true`);
  await click('[data-action="save-card"]');
  check('edit preview city',await evaluate(`cards.find(c=>c.id==='weather-1').city==='南京'`));
  const point=async(selector,dx,dy)=>{
    const r=await evaluate(`(()=>{const r=document.querySelector('#single-screen '+${JSON.stringify(selector)}).getBoundingClientRect();return{x:r.x+r.width/2,y:r.y+r.height/2}})()`);
    await send('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',buttons:1,clickCount:1,...r});
    await send('Input.dispatchMouseEvent',{type:'mouseMoved',button:'left',buttons:1,x:r.x+dx,y:r.y+dy});
    await send('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',buttons:0,clickCount:1,x:r.x+dx,y:r.y+dy});
  };
  await point('[data-card="weather-1"] .resize-handle',-156,0);
  check('card resizes by dragging',await evaluate(`cards.find(c=>c.id==='weather-1').w===3`));
  await point('[data-card="weather-1"] .card-move',156,0);
  check('card moves by dragging',await evaluate(`cards.find(c=>c.id==='weather-1').x===9`));
  await point('[data-card="weather-1"] .card-move',-312,0);
  check('overlap is rejected',await evaluate(`cards.find(c=>c.id==='weather-1').x===9`));
  await click('[data-action="open-library"]');
  check('library has every primary OEM type',await evaluate(`['music','nav','weather','calendar','member','cleanup','tpms','air'].every(t=>document.querySelector('#single-screen [data-action="add-card"][data-type="'+t+'"]'))`));
  await click('[data-action="add-card"][data-type="calendar"]');
  check('full page creates next page',await evaluate(`pageCount===3&&ui.page===2`));
  await click('[data-action="cancel-edit"]');
  check('cancel restores cards and pages',await evaluate(`cards.length===7&&pageCount===2&&cards.find(c=>c.id==='weather-1').city==='杭州'`));
  await evaluate(`beginEditing();true`);await click('[data-action="new-page"]');await click('[data-action="finish-edit"]');
  // Verify saving without an export profile; this disposable browser has no existing user preferences.
  await evaluate(`localStorage.setItem('lynk-design-v04',JSON.stringify({version:4,preferences,cards,pageCount}));true`);
  await navigate('single','dark',1920,1080,{export:'0'});
  check('empty desktop page survives reload',await evaluate(`pageCount===3&&cards.length===7`));
  await evaluate(`ui.view='settings';renderStandalone();true`);
  await click('[data-action="toggle-glass"]');
  await navigate('settings','dark',1920,1080,{export:'0'});
  check('glass preference survives reload',await evaluate(`preferences.glass===true&&document.querySelector('#single-screen [data-action="toggle-glass"]').getAttribute('aria-checked')==='true'&&getComputedStyle(document.querySelector('#single-screen .mini-screen-wrap .music-dock')).backdropFilter.includes('blur(28px)')`));
  await evaluate(`(()=>{const saved=JSON.parse(localStorage.getItem('lynk-design-v04'));delete saved.preferences.glass;localStorage.setItem('lynk-design-v04',JSON.stringify(saved));})()`);
  await navigate('settings','dark',1920,1080,{export:'0'});
  check('legacy preferences default glass off',await evaluate(`preferences.glass===false&&getComputedStyle(document.querySelector('#single-screen .settings-preview')).backdropFilter==='none'`));
  for(const theme of ['dark','light']){
    await navigate('component',theme,900,720);
    await click(seatSelector('seat-heat','left',2));await click(seatSelector('seat-vent','left',3));await click(seatSelector('seat-heat','right',1));
    check(theme+' component seat controls and mutual exclusion',await evaluate(`document.body.classList.contains('component')&&ui.climate.driverHeat===0&&ui.climate.driverVent===3&&ui.climate.passengerHeat===1&&document.querySelectorAll('#single-screen .seat-row').length===3`)&&await seatStateMatches());
    for(const [,action,zone] of seatSpecs)await click(seatSelector(action,zone,0));
    check(theme+' component explicit off',await evaluate(`ui.climate.driverHeat===0&&ui.climate.driverVent===0&&ui.climate.passengerHeat===0`)&&await seatStateMatches());
  }
  await navigate('settings');
  await click('[data-action="settings-tab"][data-tab="sources"]');
  await click('[data-key="globalDockEnabled"]');
  check('global dock design switch is independent',await evaluate(`preferences.globalDockEnabled===true&&!preferences.systemNavigationHidden`));
  await click('[data-key="systemNavigationHidden"]');
  check('system navigation design switch is independent',await evaluate(`preferences.globalDockEnabled===true&&preferences.systemNavigationHidden===true`));
  check('no runtime errors',errors.length===0);
  const exports=[
    ['home-dark','single','dark',1920,1080],['home-light','single','light',1920,1080],
    ['home-pair','pair','dark',2400,760],['secondary-dark','secondary','dark',1920,1080],['secondary-light','secondary','light',1920,1080],
    ['settings-dark','settings','dark',1920,1080],['settings-light','settings','light',1920,1080],
    ['settings-sources-dark','settings','dark',1920,1080],['settings-sources-light','settings','light',1920,1080],
    ['card-edit-mode','edit','dark',1920,1080],['card-library','library','dark',1920,1080],['card-settings','card-edit','dark',1920,1080],
    ['oem-cards-dark','cards','dark',1920,1872],['oem-cards-light','cards','light',1920,1872],
    ['dock-detail','dock','dark',1920,320],['climate-dark','component','dark',900,720],['climate-light','component','light',900,720],
    ['climate-panel','climate','dark',1920,1080],['climate-panel-light','climate','light',1920,1080],['settings-glass-on','settings','dark',1920,1080],
    ['music-panel','music','dark',1920,1080],['vehicle-panel','vehicle','dark',1920,1080],['camera-panel','camera','dark',1920,1080],
    ['home-square','settings','dark',1920,1080],['settings-motion','settings','dark',1920,1080]
  ];
  for(const [name,view,theme,width,height] of exports){
    await navigate(view,theme,width,height);
    if(view==='climate'||view==='component'){
      await click(seatSelector(theme==='light'?'seat-vent':'seat-heat','left',2));
      await click(seatSelector('seat-heat','right',1));
    }
    if(name==='settings-motion')await click('[data-action="settings-tab"][data-tab="motion"]');
    if(name.startsWith('settings-sources-'))await click('[data-action="settings-tab"][data-tab="sources"]');
    if(name==='settings-glass-on')await click('[data-action="toggle-glass"]');
    if(name==='home-square'){await evaluate(`(()=>{const r=document.querySelector('#single-screen [data-setting="radius"]');r.value=0;r.dispatchEvent(new Event('input',{bubbles:true}));document.querySelector('#single-screen [data-action="home"]').click();return true})()`);}
    const layout=await evaluate(`({width:document.documentElement.scrollWidth,height:document.documentElement.scrollHeight,clippedCards:[...document.querySelectorAll('#single-screen .widget-content')].filter(el=>[...el.children].some(c=>c.getBoundingClientRect().bottom>el.getBoundingClientRect().bottom+2)).map(el=>el.parentElement.dataset.type),clippedControls:[...document.querySelectorAll('#single-screen .mini-screen-wrap>.screen,#single-screen .climate-sheet,#single-screen .climate-glass,#single-screen .climate-sheet button,#single-screen .seat-controls,#single-screen .seat-heading,#single-screen .seat-label,#single-screen .seat-levels button,#single-screen .seat-note,#single-screen .glass-setting,#single-screen .glass-switch,#single-screen .settings-preview>.outline-button')].filter(el=>{const r=el.getBoundingClientRect(),parent=el.parentElement.closest('.mini-screen-wrap,.climate-glass,.modal-glass,.settings-preview,.screen'),p=parent.getBoundingClientRect();return r.left<p.left-1||r.right>p.right+1||r.top<p.top-1||r.bottom>p.bottom+1||el.scrollWidth>el.clientWidth+1||el.scrollHeight>el.clientHeight+1;}).map(el=>el.className||el.dataset.action)})`);
    if(layout.width>width||layout.height>height)throw Error('Export overflows: '+name+' '+JSON.stringify(layout));
    check(name+' controls fit canvas',layout.clippedControls.length===0);
    const shot=await send('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:false});
    await writeFile(path.join(root,'design',name+'.png'),Buffer.from(shot.data,'base64'));
    console.log('rendered',name,layout.clippedCards.length?'clipped: '+layout.clippedCards.join(','):'');
  }
  check('no runtime errors after exports',errors.length===0);
  await writeFile(path.join(root,'analysis/design-verification.json'),JSON.stringify({version:'V04',checks:results,runtimeErrors:errors,officialTypesCovered:11,providerComponentsMapped:14,officialFieldParity:'not verified: provider apps/device unavailable',vehicleIntegration:false,seatLevels:'demo 0–3; actual vehicle contract unverified',componentCanvas:{width:900,height:720},exports:exports.map(([name,view,theme,width,height])=>({name,view,theme,width,height}))},null,2)+'\n');
  console.log('Verified',results.length,'design checks; rendered',exports.length,'images');
} finally {
  if(ws?.readyState===1){try{const id=++seq;ws.send(JSON.stringify({id,method:'Browser.close'}));}catch{}ws.close();}
  if(chrome.exitCode===null)chrome.kill('SIGTERM');
  await delay(150);
  await rm(profile,{recursive:true,force:true}).catch(()=>{});
}
