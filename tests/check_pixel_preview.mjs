// Offline animation-preview integration check. Requires Node 22+ and Chromium.
import {spawn} from 'node:child_process';
import {mkdtemp, mkdir, rm, writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {resolve, join} from 'node:path';
import {pathToFileURL} from 'node:url';
const profile = await mkdtemp(join(tmpdir(),'crownfront-pixel-browser-'));
const browser = spawn('/usr/bin/chromium',['--headless','--no-sandbox','--disable-gpu','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],{stdio:'ignore'});
let ws;
try {
  const {readFile} = await import('node:fs/promises');
  let port;
  for(let attempt=0;attempt<100;attempt++){
    try {port=Number((await readFile(join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0]);break;}catch{await new Promise(r=>setTimeout(r,100));}
  }
  if(!port)throw new Error('Chromium did not start');
  const pages=await(await fetch(`http://127.0.0.1:${port}/json`)).json();
  const page = pages.find(target=>target.type==='page');
  if(!page)throw new Error('No preview page target');
  ws=new WebSocket(page.webSocketDebuggerUrl);
  await new Promise(r=>ws.addEventListener('open',r,{once:true}));
  let identity=0;const pending=new Map(),errors=[];
  ws.addEventListener('message',event=>{const response=JSON.parse(event.data);if(response.id){const waiter=pending.get(response.id);pending.delete(response.id);response.error?waiter.reject(response.error):waiter.resolve(response.result);}if(response.method==='Runtime.exceptionThrown')errors.push(response.params.exceptionDetails);});
  const call=(method,params={})=>new Promise((resolve,reject)=>{const id=++identity;pending.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}));});
  const evaluate=async expression=>{const result=await call('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});if(result.exceptionDetails)throw new Error(JSON.stringify(result.exceptionDetails));return result.result.value;};
  const assert=(value,message)=>{if(!value)throw new Error(message);};
  await call('Runtime.enable');await call('Page.enable');
  await call('Emulation.setDeviceMetricsOverride',{width:1200,height:650,deviceScaleFactor:1,mobile:false});
  await call('Page.navigate',{url:pathToFileURL(resolve('assets/pixel_art/preview.html')).href});
  for(let attempt=0;attempt<100;attempt++){
    if(await evaluate("typeof jobs !== 'undefined'"))break;
    await new Promise(r=>setTimeout(r,100));
  }
  assert(await evaluate("typeof jobs !== 'undefined'"),'Preview scripts failed to load: '+JSON.stringify(errors)+' '+await evaluate('location.href'));
  await evaluate('Promise.all(jobs).then(()=>true)');
  assert(await evaluate('Object.values(images).every(image=>image.complete&&image.naturalWidth>0)&&Object.keys(images).length===20'),'all original atlases load');
  assert(await evaluate("$('direction').options.length===8&&$('action').options.length===19"),'eight directions and all action poses');
  await evaluate("$('pause').click()");assert(await evaluate('paused'),'pause');
  await evaluate("$('frame').value=4;$('frame').dispatchEvent(new Event('input'))");assert(await evaluate('frame===4&&paused'),'frame scrub');
  await evaluate("$('team').value='ember';$('direction').value=7;$('action').value='flee_carry';$('walk').checked=true;draw(performance.now())");
  await call('Emulation.setDeviceMetricsOverride',{width:400,height:900,deviceScaleFactor:1,mobile:true});
  assert(await evaluate('document.documentElement.scrollWidth<=400'),'mobile preview fits');
  await call('Emulation.setDeviceMetricsOverride',{width:1200,height:650,deviceScaleFactor:1,mobile:false});
  await mkdir('tests/artifacts/pixel_browser',{recursive:true});
  const shot=await call('Page.captureScreenshot',{format:'png'});
  await writeFile('tests/artifacts/pixel_browser/preview.png',Buffer.from(shot.data,'base64'));
  await evaluate("$('pause').click()");assert(await evaluate('!paused'),'resume');
  assert(errors.length===0,'no browser exceptions');
  console.log('PASS pixel preview: all atlases, eight facings, 19 poses, pause, scrub, team selection, mobile layout and resume.');
}finally{
  ws?.close();browser.kill();
  await new Promise(r=>browser.once('exit',r));
  await rm(profile,{recursive:true,force:true,maxRetries:10,retryDelay:100});
}
