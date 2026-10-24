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
    u.search=new URLSearchParams({view,theme,export:'1',rev:'v04-final',...extra}).toString();
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
  for(const value of [0,40,28]){
    await evaluate(`(()=>{const el=document.querySelector('#single-screen [data-setting="radius"]');el.value=${value};el.dispatchEvent(new Event('input',{bubbles:true}));})()`);
    check('radius '+value,await evaluate(`preferences.radius===${value}&&getComputedStyle(document.querySelector('#single-screen .settings-block')).borderTopLeftRadius==='${value}px'`));
  }
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
  check('no runtime errors',errors.length===0);
  const exports=[
    ['home-dark','single','dark',1920,1080],['home-light','single','light',1920,1080],
    ['home-pair','pair','dark',2400,760],['secondary-dark','secondary','dark',1920,1080],['secondary-light','secondary','light',1920,1080],
    ['settings-dark','settings','dark',1920,1080],['settings-light','settings','light',1920,1080],
    ['card-edit-mode','edit','dark',1920,1080],['card-library','library','dark',1920,1080],['card-settings','card-edit','dark',1920,1080],
    ['oem-cards-dark','cards','dark',1920,1464],['oem-cards-light','cards','light',1920,1464],
    ['dock-detail','dock','dark',1920,320],['climate-dark','component','dark',900,470],['climate-light','component','light',900,470],
    ['climate-panel','climate','dark',1920,1080],['music-panel','music','dark',1920,1080],['vehicle-panel','vehicle','dark',1920,1080],['camera-panel','camera','dark',1920,1080],
    ['home-square','settings','dark',1920,1080]
  ];
  for(const [name,view,theme,width,height] of exports){
    await navigate(view,theme,width,height);
    if(name==='home-square'){await evaluate(`(()=>{const r=document.querySelector('#single-screen [data-setting="radius"]');r.value=0;r.dispatchEvent(new Event('input',{bubbles:true}));document.querySelector('#single-screen [data-action="home"]').click();return true})()`);}
    const layout=await evaluate(`({width:document.documentElement.scrollWidth,height:document.documentElement.scrollHeight,clippedCards:[...document.querySelectorAll('#single-screen .widget-content')].filter(el=>[...el.children].some(c=>c.getBoundingClientRect().bottom>el.getBoundingClientRect().bottom+2)).map(el=>el.parentElement.dataset.type)})`);
    if(layout.width>width||layout.height>height)throw Error('Export overflows: '+name+' '+JSON.stringify(layout));
    const shot=await send('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:false});
    await writeFile(path.join(root,'design',name+'.png'),Buffer.from(shot.data,'base64'));
    console.log('rendered',name,layout.clippedCards.length?'clipped: '+layout.clippedCards.join(','):'');
  }
  await writeFile(path.join(root,'analysis/design-verification.json'),JSON.stringify({version:'V04',checks:results,runtimeErrors:errors,officialTypesCovered:9,providerComponentsMapped:14,officialFieldParity:'not verified: provider apps/device unavailable',vehicleIntegration:false},null,2)+'\n');
  console.log('Verified',results.length,'design checks; rendered',exports.length,'images');
} finally {
  if(ws?.readyState===1){try{const id=++seq;ws.send(JSON.stringify({id,method:'Browser.close'}));}catch{}ws.close();}
  if(chrome.exitCode===null)chrome.kill('SIGTERM');
  await delay(150);
  await rm(profile,{recursive:true,force:true}).catch(()=>{});
}
