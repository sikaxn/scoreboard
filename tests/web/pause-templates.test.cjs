const {JSDOM}=require('jsdom');
const path=require('node:path');
const fs=require('node:fs'),assert=require('node:assert/strict');
const base=path.resolve(__dirname,'../../smartScoreboard/smartScoreboard/Assets.xcassets')+'/';
function page(path){
  const errors=[];
  const dom=new JSDOM(fs.readFileSync(base+path,'utf8'),{
    url:'http://127.0.0.1:5516/demo/scoreboard',runScripts:'dangerously',beforeParse(w){
      w.WebSocket=class {static OPEN=1;constructor(){this.readyState=1;}send(){}close(){}};
      w.fetch=async()=>({ok:true,json:async()=>({})});
      w.setInterval=()=>1;w.setTimeout=()=>1;w.requestAnimationFrame=()=>1;
      w.addEventListener('error',event=>errors.push(event.error));
    }
  });
  assert.equal(errors.length,0,`${path} initializes without errors`);
  return dom;
}
function state(){return {
  rules:{sport:'basketball',title:'Basketball',supportsScore:true,supportsPeriod:true,periodShortTitle:'Q',supportsPauses:true},
  teams:{home:{name:'HOME',score:10,pausesRemaining:2},guest:{name:'Visitors <img src=x>',score:12,pausesRemaining:1}},
  clocks:{showsGameClock:true,formattedGameClock:'10:00',formattedShotClock:'24',pauseTimer:{side:'guest',remainingSeconds:65,isRunning:true}},
  runtime:{isClockRunning:false},game:{period:1},display:{viewMode:'scoreboard'},players:{homeDisplayed:[],guestDisplayed:[],homeRoster:{players:[]},guestRoster:{players:[]}}
};}
for(const path of ['WebAPIScoreboardDemo.dataset/scoreboard.html','WebAPIOBSDemo.dataset/obs.html']){
  const dom=page(path),w=dom.window,d=w.document,s=state();
  const apply=()=>w.applyState(s);
  apply();
  assert.equal(d.getElementById('pauseOverlay').hidden,false);
  assert.equal(d.getElementById('pauseTitle').textContent,'Visitors <img src=x> Pause');
  assert.equal(d.getElementById('pauseTitle').children.length,0,'team names render as text');
  assert.equal(d.getElementById('pauseTime').textContent,'01:05');
  s.clocks.pauseTimer.isRunning=false;apply();
  assert.equal(d.getElementById('pauseStatus').textContent,'Pause Timer Paused');
  s.clocks.pauseTimer.remainingSeconds=0;apply();
  assert.equal(d.getElementById('pauseTime').textContent,'00:00');
  assert.equal(d.getElementById('pauseOverlay').hidden,false,'expired pause remains visible');
  s.clocks.pauseTimer={isRunning:false};apply();
  assert.equal(d.getElementById('pauseTitle').textContent,'Official Pause');
  assert.equal(d.getElementById('pauseTime').textContent,'');assert.equal(d.getElementById('pauseTime').hidden,true);assert.equal(d.getElementById('pauseStatus').textContent,'');
  s.display.eventLogo={path:'/api/v2/images/event-logo',id:'event'};s.teams.guest.logo={path:'/api/v2/images/team-logos/guest',id:'guest'};
  s.clocks.pauseTimer={side:'guest',isRunning:false};apply();
  assert.equal(d.getElementById('pauseTime').hidden,true,'indefinite team pause hides clock');
  assert.equal(d.getElementById('pauseOverlay').classList.contains('indefinite'),true,'indefinite labels use centered layout');
  assert.equal(d.getElementById('pauseLogo').getAttribute('src'),'/api/v2/images/team-logos/guest?v=guest','team pause shows team logo');
  s.display.showsTeamLogos=false;apply();
  assert.equal(d.getElementById('pauseLogo').getAttribute('src'),'/api/v2/images/event-logo?v=event','team logo can fall back to event');
  s.display.showsEventLogo=false;apply();assert.equal(d.getElementById('pauseLogo').classList.contains('hidden'),true,'display logo toggles respected');
  s.display.showsEventLogo=true;s.clocks.pauseTimer={isRunning:false};apply();
  assert.equal(d.getElementById('pauseLogo').getAttribute('src'),'/api/v2/images/event-logo?v=event','official pause shows event logo');
  for(const viewMode of ['teamView','playerView','eventLogo']){
    s.display.viewMode=viewMode;apply();
    assert.equal(d.getElementById('pauseOverlay').hidden,false,'pause appears in '+viewMode);
  }
  for(const viewMode of ['blackScreen','backgroundOnly']){
    s.display.viewMode=viewMode;apply();
    assert.equal(d.getElementById('pauseOverlay').hidden,true,'display control hides pause in '+viewMode);
  }
  s.display.viewMode='scoreboard';d.documentElement.lang='zh-Hans';apply();
  assert.equal(d.getElementById('pauseTitle').textContent,'官方暂停');
  s.clocks.pauseTimer=null;apply();
  assert.equal(d.getElementById('pauseOverlay').hidden,true,'cancel removes overlay');
  w.eval(`Object.assign(v2State,${JSON.stringify(s)})`);
  w.handleV2Message({schemaVersion:2,type:'scoreboard.v2.resource',resource:'clocks',payload:{data:{...s.clocks,pauseTimer:{side:'home',remainingSeconds:30,isRunning:true}}}});
  assert.equal(d.getElementById('pauseTime').textContent,'00:30','v2 clocks resource updates overlay');
  dom.window.close();
}
{
  const dom=page('WebAPICommentator.dataset/commentator.html'),w=dom.window,d=w.document,s=state();
  w.eval(`Object.assign(v2State,${JSON.stringify(s)}); renderScoreStrip()`);
  assert.equal(d.getElementById('pauseBanner').hidden,false);
  assert.match(d.getElementById('pauseBanner').textContent,/Visitors <img src=x> Pause · 01:05/);
  s.clocks.pauseTimer={isRunning:false};
  w.eval(`Object.assign(v2State,${JSON.stringify(s)}); renderScoreStrip()`);
  assert.equal(d.getElementById('pauseBanner').textContent,'Official Pause');
  s.display.eventLogo={path:'/api/v2/images/event-logo',id:'event'};
  w.eval(`Object.assign(v2State,${JSON.stringify(s)}); renderScoreStrip()`);
  assert.equal(d.getElementById('pauseBannerLogo').getAttribute('src'),'/api/v2/images/event-logo?v=event');
  w.eval("setLanguagePreference('zh')");
  assert.equal(d.getElementById('pauseBanner').textContent,'官方暂停');
  s.clocks.pauseTimer=null;
  w.eval(`Object.assign(v2State,${JSON.stringify(s)}); renderScoreStrip()`);
  assert.equal(d.getElementById('pauseBanner').hidden,true);
  dom.window.close();
}
console.log('Passed pause template DOM checks: scoreboard, OBS, commentator, team/official labels, countdown, expiry, cancel, display modes, Chinese, and v2 updates.');
