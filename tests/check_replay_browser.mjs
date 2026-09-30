// Local browser integration check. Requires Node 22+ and Chromium.
// Usage: node tests/check_replay_browser.mjs tests/artifacts/simulation_timelapse.html
import {spawn} from 'node:child_process';
import {writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
const file=resolve(process.argv[2]||'tests/artifacts/replay_smoke.html');
const browser=spawn('/usr/bin/chromium',['--headless','--no-sandbox','--disable-gpu','--remote-debugging-port=9333','--user-data-dir=/tmp/crownfront-browser','about:blank'],{stdio:'ignore'});
let ws;
try {
 let pages;for(let i=0;i<80;i++){try{pages=await(await fetch('http://127.0.0.1:9333/json')).json();break}catch{await new Promise(r=>setTimeout(r,100))}}
 ws=new WebSocket(pages[0].webSocketDebuggerUrl);await new Promise(r=>ws.addEventListener('open',r,{once:true}));let id=0;const pending=new Map(),errors=[];ws.addEventListener('message',e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(m.error):p.resolve(m.result)}if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails)});
 const call=(method,params={})=>new Promise((resolve,reject)=>{const n=++id;pending.set(n,{resolve,reject});ws.send(JSON.stringify({id:n,method,params}))});
 const evaluate=async expression=>{const r=await call('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});if(r.exceptionDetails)throw new Error(JSON.stringify(r.exceptionDetails));return r.result.value};
 const assert=(condition,message)=>{if(!condition)throw new Error(message)};
 await call('Runtime.enable');await call('Page.enable');await call('Emulation.setDeviceMetricsOverride',{width:1400,height:1000,deviceScaleFactor:1,mobile:false});
 await call('Page.navigate',{url:pathToFileURL(file).href});for(let i=0;i<100;i++){if(await evaluate("typeof frames !== 'undefined' && frames.length>0 && $('run').options.length>0"))break;await new Promise(r=>setTimeout(r,100))}
 assert(await evaluate("frames.length>1 && $('play').textContent==='Play' && $('speed').value==='16'"),'initial state');
 await evaluate("position=Math.max(0,activeRun.duration-2);render();$('play').click()");await new Promise(r=>setTimeout(r,600));assert(await evaluate("!playing && position===activeRun.duration && $('outcome').textContent.length>0"),'timeout stopping');
 await evaluate("$('restart').click()");assert(await evaluate('position===0 && !playing'),'restart');
 await evaluate("$('seek').value=2;$('seek').dispatchEvent(new Event('input'))");assert(await evaluate('position===2 && !playing'),'scrub');
 await call('Emulation.setDeviceMetricsOverride',{width:400,height:900,deviceScaleFactor:1,mobile:true});assert(await evaluate('document.documentElement.scrollWidth<=400'),'mobile width');
 await call('Emulation.setDeviceMetricsOverride',{width:1400,height:1000,deviceScaleFactor:1,mobile:false});await evaluate("position=activeRun.duration*.7;render()");const shot=await call('Page.captureScreenshot',{format:'png'});await writeFile('/tmp/crownfront-replay.png',Buffer.from(shot.data,'base64'));await evaluate("for(const frame of frames){position=frame.t;render()}position=0;render()");
 await evaluate("if(moments.length){const marker=$('markers').children[0];marker.click();if(playing||position!==Math.min(moments[0].t,activeRun.duration))throw new Error('event jump')} const h=hitEntities.find(h=>h.e[1]==='king'); const rect=$('map').getBoundingClientRect();$('map').dispatchEvent(new MouseEvent('mousemove',{clientX:rect.left+h.x*rect.width/1380,clientY:rect.top+h.y*rect.height/780}));if($('tooltip').hidden||!$('tooltip').textContent.includes('HP'))throw new Error('tooltip');$('speed').value='32';$('play').click();if(!playing||+$('speed').value!==32)throw new Error('speed');pause();");
 await evaluate("if(runs.length>1){$('run').value=1;$('run').dispatchEvent(new Event('change'));if(position!==0||playing||activeRun!==runs[1])throw new Error('run switching')}");
 await evaluate("const legacy={...runs[0]};delete legacy.map;delete legacy.replay_version;legacy.timeline=legacy.timeline.map(s=>({...s,entities:s.entities.map(e=>e.slice(0,5))}));runs.push(legacy);let option=document.createElement('option');option.value=runs.length-1;$('run').append(option);$('run').value=runs.length-1;$('run').dispatchEvent(new Event('change'));position=legacy.duration/2;render();if(!frames.length||!$('notice').hidden)throw new Error('legacy replay');");
 await evaluate("runs.push({scenario:'failure',outcome:'technical_failure',error:'Synthetic failure'});let failedOption=document.createElement('option');failedOption.value=runs.length-1;$('run').append(failedOption);$('run').value=runs.length-1;$('run').dispatchEvent(new Event('change'));if($('teams').children.length||!$('play').disabled||$('notice').hidden||!$('recap').textContent.includes('Technical failure'))throw new Error('failure state');");
 assert(!errors.length,'browser exceptions: '+JSON.stringify(errors));console.log('Browser checks passed: playback, final stop, restart, seek, markers, tooltips, speed, run switching, responsive layout, legacy replay, technical failure.');
}finally{ws?.close();browser.kill();}
