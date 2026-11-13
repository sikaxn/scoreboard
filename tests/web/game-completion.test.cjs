const {test}=require('node:test');
const {JSDOM}=require('jsdom');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const assets=path.resolve(__dirname,'../../smartScoreboard/smartScoreboard/Assets.xcassets');
const tick=()=>new Promise(resolve=>setImmediate(resolve));
const completion=outcome=>({outcome,homeName:'Home <img src=x>',guestName:'Visitors',homeScore:7,guestScore:12,showsScore:true,completedAtUnixTime:1});
function state(sport='basketball') {return {
  rules:{sport,title:sport,supportsScore:!['chess','debate'].includes(sport),supportsPeriod:true,periodShortTitle:'P',scoreStepOptions:[1],supportsShotClock:sport==='basketball',usesChessClocks:sport==='chess'},
  game:{period:1,defaultClockSeconds:600,homePenaltyTimers:[],guestPenaltyTimers:[]},runtime:{isClockRunning:false},
  teams:{home:{name:'Home <img src=x>',score:7},guest:{name:'Visitors',score:12}},
  clocks:{showsGameClock:sport!=='volleyball',formattedGameClock:'10:00',formattedShotClock:'24'},
  players:{homeDisplayed:[],guestDisplayed:[],homeRoster:{players:[]},guestRoster:{players:[]}},
  control:{webEnabled:true},display:{viewMode:'scoreboard'}
};}
function page(file,before) {
 const errors=[];
 const dom=new JSDOM(fs.readFileSync(path.join(assets,file),'utf8'),{url:'http://127.0.0.1:5516/demo/scoreboard',runScripts:'dangerously',beforeParse(w){
  w.WebSocket=class{static OPEN=1;constructor(){this.readyState=1;}send(){}close(){}};
  w.fetch=async()=>({ok:true,json:async()=>({})});w.setInterval=()=>1;w.setTimeout=()=>1;w.requestAnimationFrame=()=>1;
  w.addEventListener('error',e=>errors.push(e.error));before?.(w);
 }});
 assert.deepEqual(errors,[]);return dom;
}
for(const file of ['WebAPIScoreboardDemo.dataset/scoreboard.html','WebAPIOBSDemo.dataset/obs.html']) {
 test(`${file}: all sports, outcomes, view modes, undo and v2 updates`,()=>{
  const dom=page(file),w=dom.window,d=w.document;
  for(const sport of ['simple','basketball','volleyball','soccer','hockey','chess','debate','custom']) {
   const s=state(sport);
   for(const outcome of ['homeWin','guestWin','tie','aborted']) {
    s.game.completion=completion(outcome);w.applyState(s);
    assert.equal(d.getElementById('completionOverlay').hidden,false,`${sport}/${outcome}`);
    assert.equal(d.getElementById('completionScore').textContent,'7 – 12');
    assert.equal(d.getElementById('completionTeams').children.length,0);
    assert.equal(d.getElementById('completionOutcome').textContent,{homeWin:'Home <img src=x> wins',guestWin:'Visitors wins',tie:'Tie',aborted:'Game aborted'}[outcome]);
   }
   for(const viewMode of ['scoreboard','teamView','playerView','eventLogo']) {
    s.display.viewMode=viewMode;w.applyState(s);assert.equal(d.getElementById('completionOverlay').hidden,false);
   }
   for(const viewMode of ['blackScreen','backgroundOnly']) {
    s.display.viewMode=viewMode;w.applyState(s);assert.equal(d.getElementById('completionOverlay').hidden,true);
   }
   s.display.viewMode='scoreboard';s.game.completion=null;w.applyState(s);assert.equal(d.getElementById('completionOverlay').hidden,true);
  }
  const s=state('volleyball');s.game.completion={...completion('homeWin'),homePeriodWins:3,guestPeriodWins:1};
  w.eval(`Object.assign(v2State,${JSON.stringify(s)})`);
  w.handleV2Message({schemaVersion:2,type:'scoreboard.v2.resource',resource:'game',payload:{data:s.game}});
  assert.equal(d.getElementById('completionScore').textContent,'3 – 1');
  d.documentElement.lang='zh-Hans';s.game.completion.outcome='aborted';w.applyState(s);
  assert.equal(d.getElementById('completionOutcome').textContent,'比赛中止');
  s.game.completion.showsScore=false;w.applyState(s);assert.equal(d.getElementById('completionScore').hidden,true);
  dom.window.close();
 });
}
test('Remote control: choose outcome, freeze every action, and authenticated undo in every sport',async()=>{
 const source=fs.readFileSync(path.join(assets,'../ScoreboardControl.swift'),'utf8');
 const operations=[...source.matchAll(/\.init\(id: "([^"]+)", title: "([^"]+)", parameters: \[([^\]]*)\], capability: "([^"]*)"\)/g)].map(m=>({id:m[1],title:m[2],parameters:[...m[3].matchAll(/"([^"]+)"/g)].map(p=>p[1]),capability:m[4]}));
 for(const sport of ['simple','basketball','volleyball','soccer','hockey','chess','debate','custom']) {
  const s=state(sport),posts=[],intervals=[];
  const dom=page('WebAPIControlDemo.dataset/index.html',w=>{
   w.WebSocket=class{static OPEN=1;constructor(){this.readyState=0;}send(){}close(){}};w.confirm=()=>true;w.AbortSignal.timeout=()=>undefined;w.setInterval=fn=>{intervals.push(fn);return intervals.length;};
   w.fetch=async(url,options)=>{
    if(url.endsWith('/operations'))return {ok:true,json:async()=>operations};
    if(options?.method==='POST'){
     const command=JSON.parse(options.body);posts.push(command);
     if(command.action==='game.complete')s.game.completion=completion(command.text);
     if(command.action==='game.undoComplete')s.game.completion=null;
     return {ok:true,json:async()=>({success:true})};
    }
    return {ok:true,json:async()=>s};
   };
  }),w=dom.window,d=w.document,$=id=>d.getElementById(id);
  await tick();await tick();
  $('key').value='1234567890ABCDEF';$('key').dispatchEvent(new w.Event('input'));
  assert.equal($('completeGame').disabled,false,sport);
  $('completeGame').click();assert.equal($('completionChoice').hidden,false);
  $('outcome').value='guestWin';$('confirmComplete').click();await tick();await tick();
  assert.equal(posts.at(-1).action,'game.complete');assert.equal(posts.at(-1).text,'guestWin');
  assert.equal($('finalResult').hidden,false);assert.equal($('finalOutcome').textContent,'Visitors wins');
  assert.equal($('apply').disabled,true);assert.equal($('action').disabled,true);
  for(const button of d.querySelectorAll('#quick button,#pauseControls button,#maintenance button,#completeGame,#confirmComplete,#cancelComplete'))assert.equal(button.disabled,true,`${sport}/${button.textContent}`);
  assert.equal($('undoComplete').disabled,false);
  const before=posts.length;w.eval("send({action:'score.adjust',side:'home',value:1})");await tick();assert.equal(posts.length,before);
  $('key').value='';$('key').dispatchEvent(new w.Event('input'));assert.equal($('undoComplete').disabled,true);
  $('key').value='1234567890ABCDEF';$('key').dispatchEvent(new w.Event('input'));$('undoComplete').click();await tick();await tick();
  assert.equal(posts.at(-1).action,'game.undoComplete');assert.equal($('finalResult').hidden,true);assert.equal($('completeGame').disabled,false);
  dom.window.close();
 }
});
test('Commentator displays declared result and clears it after undo',()=>{
 const dom=page('WebAPICommentator.dataset/commentator.html'),w=dom.window,d=w.document,s=state();
 s.game.completion=completion('guestWin');
 w.eval(`Object.assign(v2State,${JSON.stringify(s)}); renderScoreStrip()`);
 assert.equal(d.getElementById('completionBanner').hidden,false);assert.match(d.getElementById('completionBanner').textContent,/Visitors wins/);assert.equal(d.getElementById('completionBanner').children.length,0);
 s.game.completion=null;
 w.eval(`commentator={summary:{completion:${JSON.stringify(completion('guestWin'))}}}; Object.assign(v2State,${JSON.stringify(s)}); renderScoreStrip()`);
 assert.equal(d.getElementById('completionBanner').hidden,true,'fresh game state clears a stale commentator result after undo');
 dom.window.close();
});
