#!/usr/bin/env node
// Isolated local design review; never opens the user's browser profile.
import {spawn} from 'node:child_process';
import {mkdtemp, readFile, writeFile, rm} from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {fileURLToPath, pathToFileURL} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const profile=await mkdtemp(path.join(os.tmpdir(),'lynk-vehicle-cards-'));
const chrome=spawn(process.env.LYNK_REVIEW_CHROME||'google-chrome',[
  '--headless=new','--disable-gpu','--disable-background-networking',
  '--disable-component-update','--disable-sync','--disable-extensions',
  '--no-first-run','--no-default-browser-check','--hide-scrollbars',
  '--remote-debugging-address=127.0.0.1','--remote-debugging-port=0',
  '--user-data-dir='+profile,'about:blank',
],{stdio:['ignore','ignore','pipe']});
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
let stderr='',ws,sequence=0;
chrome.stderr.on('data',data=>{stderr+=data;});
const pending=new Map(),errors=[],checks=[],shots=[];
try {
  let port;
  for(let i=0;i<100;i++){
    try{port=(await readFile(path.join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];break;}catch{}
    if(chrome.exitCode!==null)throw Error(stderr.slice(-1000));
    await delay(100);
  }
  if(!port)throw Error('Review browser did not start');
  const tab=await (await fetch(`http://127.0.0.1:${port}/json/new?about:blank`,{method:'PUT'})).json();
  ws=new WebSocket(tab.webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{
    ws.addEventListener('open',resolve,{once:true});
    ws.addEventListener('error',reject,{once:true});
  });
  ws.addEventListener('message',event=>{
    const message=JSON.parse(event.data);
    if(message.id){
      const request=pending.get(message.id);
      if(request){pending.delete(message.id);message.error?request.reject(Error(JSON.stringify(message.error))):request.resolve(message.result);}
    }
    if(message.method==='Runtime.exceptionThrown')errors.push(message.params.exceptionDetails);
  });
  const send=(method,params={})=>new Promise((resolve,reject)=>{
    const id=++sequence;pending.set(id,{resolve,reject});
    ws.send(JSON.stringify({id,method,params}));
  });
  const evaluate=async expression=>{
    const result=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});
    if(result.exceptionDetails)throw Error(result.exceptionDetails.exception?.description||result.exceptionDetails.text);
    return result.result.value;
  };
  const check=async(name,expression)=>{
    const passed=Boolean(await evaluate(expression));
    checks.push({name,passed});
    if(!passed)throw Error('Design check failed: '+name);
  };
  await send('Page.enable');await send('Runtime.enable');
  const navigate=async(theme,extra={},view='vehicle-cards',height=1080)=>{
    await send('Emulation.setDeviceMetricsOverride',{width:1920,height,deviceScaleFactor:1,mobile:false});
    const url=pathToFileURL(path.join(root,'design/index.html'));
    url.search=new URLSearchParams({view,theme,export:'1',...extra}).toString();
    await send('Page.navigate',{url:url.href});
    let ready=false;
    for(let i=0;i<100;i++){
      ready=await evaluate(`location.href===${JSON.stringify(url.href)}&&document.readyState==='complete'`);
      if(ready)break;
      await delay(50);
    }
    if(!ready)throw Error('Design did not finish loading');
    await evaluate('(async()=>{await document.fonts.ready;await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));})()');
  };
  const capture=async(name,height=1080)=>{
    await check(name+' fits canvas',`document.documentElement.scrollWidth<=1920&&document.documentElement.scrollHeight<=${height}`);
    await check(name+' contents fit',`[...document.querySelectorAll('#single-screen :is(.battery-card,.air-card,.vehicle-card) .widget-content')].every(el=>{const box=el.getBoundingClientRect();return [...el.querySelectorAll('*')].every(child=>{const r=child.getBoundingClientRect();return r.left>=box.left-1&&r.right<=box.right+1&&r.top>=box.top-1&&r.bottom<=box.bottom+1;});})`);
    const shot=await send('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:false});
    await writeFile(path.join(root,'design',name+'.png'),Buffer.from(shot.data,'base64'));
    shots.push(name+'.png');
  };
  for(const theme of ['dark','light']){
    for(const state of ['live','disconnected','partial']){
      await navigate(theme,{state});
      await check('default layout stays unchanged',"cards.length===7&&!cards.some(c=>['battery','air','vehicle'].includes(c.type))");
      await check('examples clearly labelled',"document.querySelector('#single-screen').textContent.includes('示例数据')");
      await check('minimum row has all three cards',"document.querySelectorAll('#single-screen .minimum .widget-card').length===3");
      await check('independent mode, energy and external charging rows',"[...document.querySelectorAll('#single-screen .battery-card')].every(el=>el.textContent.includes('驾驶模式')&&el.textContent.includes('能量流')&&el.textContent.includes('外接充电待同步'))");
      if(state==='live')await check('95 percent has exact track ratio',"[...document.querySelectorAll('#single-screen .battery-level')].every(el=>Math.abs(el.firstElementChild.getBoundingClientRect().width/el.getBoundingClientRect().width-.95)<.001)");
      if(state==='disconnected')await check('disconnection hides every sample',"[...document.querySelectorAll('#single-screen .vehicle-reading b')].every(el=>el.textContent==='—')");
      if(state==='partial')await check('air fields remain independent',"[...document.querySelectorAll('#single-screen .air-card')].every(el=>el.textContent.includes('12')&&el.textContent.includes('暂无数据'))");
      await capture(`vehicle-cards-${theme}-${state}`);
    }
  }
  for(const radius of ['0','40']){
    await navigate(radius==='0'?'light':'dark',{radius,glass:radius==='40'?'1':'0',palette:'blue'});
    await check('radius '+radius+' reaches cards',`[...document.querySelectorAll('#single-screen .widget-card')].every(el=>getComputedStyle(el).borderTopLeftRadius==='${radius}px')`);
    await capture('vehicle-cards-radius-'+radius);
  }
  // Only local prototype state changes; export=1 disables persistence.
  await navigate('dark',{},'single');
  await check('library adds, edits and serializes the same three types',`(()=>{
    const before=JSON.stringify(defaultCards());beginEditing();
    for(const type of ['battery','air','vehicle']){
      ui.modal='library';renderStandalone();
      document.querySelector('#single-screen [data-action="add-card"][data-type="'+type+'"]').click();
      const card=cards.at(-1);if(card.type!==type||card.w!==4||card.h!==3)return false;
      document.querySelector('#single-screen [data-action="edit-card"][data-id="'+card.id+'"]').click();
      if(!document.querySelector('#single-screen [data-action="choose-size"][data-w="4"][data-h="3"].selected'))return false;
      document.querySelector('#single-screen [data-action="choose-size"][data-w="3"][data-h="2"]').click();
      document.querySelector('#single-screen input[name="card-title"]').value='我的'+cardCatalog[type].name;
      document.querySelector('#single-screen [data-action="save-card"]').click();
    }
    const saved=JSON.parse(layoutSnapshot());
    return saved.cards.length===10&&JSON.stringify(saved.cards.slice(0,7))===before&&saved.cards.slice(7).every(c=>c.w===3&&c.h===2&&c.title.startsWith('我的'));
  })()`);
  for(const theme of ['dark','light']){
    await navigate(theme,{},'cards',1872);
    await capture('oem-cards-'+theme,1872);
  }
  if(errors.length)throw Error('Browser runtime errors: '+JSON.stringify(errors));
  await writeFile(path.join(root,'design/vehicle-cards-report.json'),JSON.stringify({
    data:'fixed review examples, no vehicle connection',checks,shots,runtimeErrors:errors,
  },null,2)+'\n');
  console.log(`Vehicle cards: ${checks.length} checks passed; ${shots.length} images exported`);
} finally {
  if(ws?.readyState===1){ws.send(JSON.stringify({id:++sequence,method:'Browser.close'}));ws.close();}
  if(chrome.exitCode===null)chrome.kill('SIGTERM');
  await delay(150);
  await rm(profile,{recursive:true,force:true}).catch(()=>{});
}
