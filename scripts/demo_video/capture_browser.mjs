#!/usr/bin/env node
// Capture actual browser pages only after the live game state arrives.
import {spawn} from 'node:child_process';
import {mkdtemp,readFile,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';

const [browser,url,directory,name,language='en']=process.argv.slice(2);
const profile=await mkdtemp(join(tmpdir(),'scoreboard-demo-browser-'));
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const child=spawn(browser,['--no-sandbox','--disable-gpu','--no-first-run',
  '--no-default-browser-check','--hide-scrollbars','--disable-background-networking',
  '--window-size=1920,1080','--remote-debugging-port=0',`--user-data-dir=${profile}`,
  ...(language==='zh-Hans'?['--lang=zh-CN','--accept-lang=zh-CN,zh,en']:[])] ,{stdio:'ignore'});
let websocket;
try {
  let port;
  for(let attempt=0;attempt<60;attempt++){
    try{port=(await readFile(join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];break;}
    catch{await pause(100);}
  }
  if(!port)throw new Error('Capture browser did not start');
  const page=await (await fetch(`http://127.0.0.1:${port}/json/new?${encodeURIComponent(url)}`,{method:'PUT'})).json();
  websocket=new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{websocket.addEventListener('open',resolve,{once:true});websocket.addEventListener('error',reject,{once:true});});
  const pending=new Map();let sequence=0;
  websocket.addEventListener('message',event=>{
    const data=JSON.parse(event.data);const request=pending.get(data.id);
    if(request){pending.delete(data.id);data.error?request.reject(new Error(JSON.stringify(data.error))):request.resolve(data.result);}
  });
  const command=(method,params={})=>new Promise((resolve,reject)=>{
    const id=++sequence;pending.set(id,{resolve,reject});websocket.send(JSON.stringify({id,method,params}));
  });
  await command('Emulation.setDeviceMetricsOverride',{width:1920,height:1080,deviceScaleFactor:1,mobile:false});
  const teams=language==='zh-Hans'?['北方队','南方队']:['NORTH','SOUTH'];
  let dom='';
  for(let attempt=0;attempt<60;attempt++){
    const result=await command('Runtime.evaluate',{expression:'document.documentElement.outerHTML',returnByValue:true});
    dom=result.result.value||'';
    if(teams.every(team=>dom.toUpperCase().includes(team)))break;
    await pause(100);
  }
  if(!teams.every(team=>dom.toUpperCase().includes(team)))throw new Error(`${name}: live demo teams did not arrive`);
  await command('Runtime.evaluate',{expression:'document.fonts.ready.then(()=>true)',awaitPromise:true,returnByValue:true});
  await pause(250);
  const screenshot=await command('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:false});
  const result=await command('Runtime.evaluate',{expression:'document.documentElement.outerHTML',returnByValue:true});
  await writeFile(join(directory,`${name}.png`),Buffer.from(screenshot.data,'base64'));
  await writeFile(join(directory,`${name}.html`),result.result.value);
  process.stdout.write(JSON.stringify({page:name,liveStateVerified:true,language})+'\n');
}finally{
  websocket?.close();
  child.kill('SIGTERM');
  await Promise.race([new Promise(resolve=>child.once('exit',resolve)),pause(1000)]);
  await rm(profile,{recursive:true,force:true,maxRetries:3,retryDelay:100});
}
