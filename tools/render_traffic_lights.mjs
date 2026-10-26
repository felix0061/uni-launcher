#!/usr/bin/env node
// Isolated local design review; never opens the user's browser profile.
import {spawn} from 'node:child_process';
import {mkdtemp, readFile, writeFile, rm} from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {fileURLToPath, pathToFileURL} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const profile=await mkdtemp(path.join(os.tmpdir(),'uni-traffic-light-'));
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
  const url=pathToFileURL(path.join(root,'design/traffic-lights.html')).href;
  await send('Page.navigate',{url});
  for(let i=0;i<100;i++){
    if(await evaluate(`location.href===${JSON.stringify(url)}&&document.readyState==='complete'`))break;
    await delay(50);
  }
  await evaluate('(async()=>{await document.fonts.ready;await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));})()');
  await check('1920x1080 canvas fits',"document.documentElement.scrollWidth===1920&&document.documentElement.scrollHeight===1080");
  await check('card content is contained',`[...document.querySelectorAll('.card')].every(el=>{const b=el.getBoundingClientRect();return [...el.querySelectorAll('*')].filter(c=>!c.closest('svg')).every(c=>{const r=c.getBoundingClientRect();return r.left>=b.left-1&&r.right<=b.right+1&&r.top>=b.top-1&&r.bottom<=b.bottom+1;});})`);
  await check('scenes contain every card',`[...document.querySelectorAll('.scene')].every(el=>{const b=el.getBoundingClientRect();return [...el.querySelectorAll('.card')].every(c=>c.getBoundingClientRect().bottom<=b.bottom);})`);
  await check('examples marked as examples',"document.querySelector('.note').textContent.includes('示例数据')");
  if(errors.length)throw Error(JSON.stringify(errors));
  const shot=await send('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:false});
  await writeFile(path.join(root,'design/traffic-lights.png'),Buffer.from(shot.data,'base64'));
  await writeFile(path.join(root,'design/traffic-lights-report.json'),JSON.stringify({checks,runtimeErrors:errors},null,2)+'\n');
  console.log('Traffic-light design: '+checks.length+' layout checks passed');
} finally {
  if(ws?.readyState===1){ws.send(JSON.stringify({id:++sequence,method:'Browser.close'}));ws.close();}
  if(chrome.exitCode===null)chrome.kill('SIGTERM');
  await delay(150);
  await rm(profile,{recursive:true,force:true}).catch(()=>{});
}
