#!/usr/bin/env node
// Isolated local design review; never opens the user's browser profile.
import {spawn} from 'node:child_process';
import {mkdtemp, readFile, writeFile, rm} from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {fileURLToPath, pathToFileURL} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const profile=await mkdtemp(path.join(os.tmpdir(),'uni-blue-glass-'));
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
  await send('Emulation.setDeviceMetricsOverride',{width:1920,height:1080,deviceScaleFactor:1,mobile:false});
  const variants=[['home','dark'],['home','light'],['vehicle','dark'],['settings','dark']];
  for(const [view,mode] of variants){
    const url=new URL(pathToFileURL(path.join(root,'design/blue-glass/index.html')));
    url.search=new URLSearchParams({view,mode,export:'1'}).toString();
    await send('Page.navigate',{url:url.href});
    for(let i=0;i<100;i++){
      if(await evaluate(`location.href===${JSON.stringify(url.href)}&&document.readyState==='complete'`))break;
      await delay(50);
    }
    await evaluate('(async()=>{await document.fonts.ready;await Promise.all([...document.images].map(i=>i.decode().catch(()=>{})));await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));})()');
    const prefix=view+'-'+mode;
    await check(prefix+': canvas 1920x1080',"document.querySelector('.screen').clientWidth===1920&&document.querySelector('.screen').clientHeight===1080");
    await check(prefix+': dock is full width and flush with bottom',`(()=>{const r=document.querySelector('.dock').getBoundingClientRect();return r.left===0&&r.right===1920&&r.bottom===1080&&r.height===96&&getComputedStyle(document.querySelector('.dock')).borderRadius==='0px'})()`);
    await check(prefix+': all panel children fit',`[...document.querySelectorAll('.card')].every(el=>{const b=el.getBoundingClientRect();return [...el.querySelectorAll('h1,h2,p,.card-heading,.micro-footer,.reading,.traffic-light,.temperature,.time-labels,.lyrics,.settings-row')].every(c=>{const r=c.getBoundingClientRect();return r.left>=b.left-1&&r.right<=b.right+1&&r.top>=b.top-1&&r.bottom<=b.bottom+1})})`);
    await check(prefix+': all primary panels clear dock',`[...document.querySelectorAll('.card')].every(el=>el.getBoundingClientRect().bottom<document.querySelector('.dock').getBoundingClientRect().top)`);
    await check(prefix+': no live blur or animated visual filters',`[...document.querySelectorAll('.screen *')].every(el=>{const s=getComputedStyle(el);return s.backdropFilter==='none'&&s.filter==='none'&&s.animationName==='none'})`);
    await check(prefix+': assets decoded',`[...document.images].every(i=>i.complete&&i.naturalWidth>0)`);
    if(view==='vehicle')await check('vehicle: horizontal car and separate tyre labels',`(()=>{const car=document.querySelector('.tire-stage>img').getBoundingClientRect();return car.width>car.height*2&&[...document.querySelectorAll('.tire-reading')].every(el=>{const r=el.getBoundingClientRect();return r.right<=car.left||r.left>=car.right||r.bottom<=car.top||r.top>=car.bottom})})()`);
    if(view==='settings')await check('settings: preview ratio is 16:9',`(()=>{const r=document.querySelector('.mini-preview').getBoundingClientRect();return Math.abs(r.width/r.height-16/9)<.01})()`);
    if(view!=='settings')await check(prefix+': examples labelled',"document.querySelector('.preview-mark').textContent.includes('示例')");
    if(errors.length)throw Error(JSON.stringify(errors));
    const shot=await send('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:false});
    await writeFile(path.join(root,'design/blue-glass/'+prefix+'.png'),Buffer.from(shot.data,'base64'));
    shots.push(prefix+'.png');
  }
  await writeFile(path.join(root,'design/blue-glass/review-report.json'),JSON.stringify({checks,runtimeErrors:errors,screenshots:shots},null,2)+'\n');
  console.log('Blue glass design: '+checks.length+' layout checks passed');

} finally {
  if(ws?.readyState===1){ws.send(JSON.stringify({id:++sequence,method:'Browser.close'}));ws.close();}
  if(chrome.exitCode===null)chrome.kill('SIGTERM');
  await delay(150);
  await rm(profile,{recursive:true,force:true}).catch(()=>{});
}
