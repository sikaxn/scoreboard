const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { JSDOM } = require('jsdom');
const directory = path.resolve(__dirname, '../../demo_player_square_clips');
const html = fs.readFileSync(path.join(directory, 'index.html'), 'utf8');
const flush = () => new Promise(resolve => setImmediate(resolve));

function page(url = 'http://127.0.0.1:5516/user/') {
  const sockets = [], timers = new Map(), errors = [], loads = [];
  const readiness = new WeakMap();
  let timerID = 0, plays = 0;
  const dom = new JSDOM(html, {
    url, runScripts: 'dangerously',
    beforeParse(w) {
      w.WebSocket = class {
        constructor(url) { this.url = url; sockets.push(this); }
        send(message) { this.sent = JSON.parse(message); }
        close() { this.onclose?.(); }
      };
      Object.defineProperty(w.HTMLMediaElement.prototype, 'readyState', { get() { return readiness.get(this) ?? 4; } });
      Object.defineProperty(w.HTMLMediaElement.prototype, 'duration', { get() { return 4; } });
      w.HTMLMediaElement.prototype.play = function () { plays++; return Promise.resolve(); };
      w.HTMLMediaElement.prototype.pause = function () {};
      w.HTMLMediaElement.prototype.load = function () { loads.push(this.src); };
      w.Element.prototype.scrollTo = function ({ top }) { this.scrollTop = top; };
      w.setTimeout = (callback, delay) => { timers.set(++timerID, { callback, delay }); return timerID; };
      w.clearTimeout = id => timers.delete(id);
      w.requestAnimationFrame = callback => queueMicrotask(callback);
      w.cancelAnimationFrame = () => {};
      w.addEventListener('error', event => errors.push(event.error));
    }
  });
  const w = dom.window, d = w.document, obs = d.getElementById('obs');
  sockets[0].onopen();
  obs.contentDocument.open();
  obs.contentDocument.write('<!doctype html><html><head></head><body><main id="playerBug">Old lineup</main><main id="scorebug"><section class="teams"><div class="team home"><span id="homeName"></span><span id="homeScore" class="score">10</span></div><div class="team guest"><span id="guestName"></span><span id="guestScore" class="score">12</span></div></section><section class="clockbox"><span id="clock">10:00</span></section></main></body></html>');
  obs.contentDocument.close();
  obs.dispatchEvent(new w.Event('load'));
  function update(resource, data) {
    sockets.at(-1).onmessage({ data: JSON.stringify({ schemaVersion: 2, type: 'scoreboard.v2.resource', resource, payload: { data } }) });
  }
  function display(mode, mainMode = 'scoreboard', settle = true) {
    update('display', { viewMode: mainMode, playerViewRosterScope: 'activeLineup', broadcastControl: { assignments: [
      { displayID: 2, effectiveRenderMode: 'playerView' }, { displayID: 3, effectiveRenderMode: mode }
    ] } });
    if (settle) finishScenes();
  }
  function finishScenes() {
    for (let iteration = 0; iteration < 3; iteration++) {
      for (const panel of [d.getElementById('introduction'), d.getElementById('teamPresentation'), d.getElementById('eventPresentation'), obs]) {
        if (panel.dataset.motion !== 'exiting' || panel.hidden) continue;
        const target = panel === obs ? obs : panel.firstElementChild;
        target.dispatchEvent(Object.assign(new w.Event('animationend'), { animationName: panel === obs ? 'scorebar-out' : 'panel-out' }));
      }
    }
  }
  const active = () => d.querySelector('.pose-video.is-active');
  async function ended() { active().dispatchEvent(new w.Event('ended')); await flush(); }
  function finishExit() {
    d.querySelector('.stage').dispatchEvent(Object.assign(new w.Event('animationend'), { animationName: 'panel-out' }));
  }
  function timer(delay) {
    const entry = [...timers.entries()].find(([, timer]) => timer.delay === delay);
    assert.ok(entry, `timer ${delay} exists`);
    timers.delete(entry[0]); entry[1].callback();
  }
  function seed(players = roster()) {
    update('game', { eventName: 'Championship' });
    update('teams', { home: { name: 'Blue Team', score: 10 }, guest: { name: 'Red Team', score: 12 } });
    update('players', players);
  }
  return { dom, w, d, obs, sockets, timers, errors, loads, readiness, update, display, active, ended, finishExit, finishScenes, timer, seed,
    intro: d.getElementById('introduction'), videos: [...d.querySelectorAll('video')], plays: () => plays };
}

function roster() {
  const home = Array.from({ length: 12 }, (_, i) => ({ id: `home-${i}`, name: `Home ${i + 1}`, number: String(i + 1) }));
  const guest = Array.from({ length: 12 }, (_, i) => ({ id: `guest-${i}`, name: `Guest ${i + 1}`, number: String(i + 1) }));
  return { homeRoster: { players: home }, guestRoster: { players: guest }, homeDisplayed: [home[5]], guestDisplayed: [guest[11]] };
}

test('shows one complete team roster at a time and plays home then guest exactly once', async () => {
  const p = page(); p.seed(); p.display('playerView'); await flush();
  assert.equal(p.d.querySelectorAll('.player-row').length, 12, 'complete home roster even with active-lineup scope');
  assert.equal(p.d.getElementById('eventName').textContent, 'Championship');
  assert.equal(p.d.getElementById('progress'), null);
  assert.equal(p.intro.dataset.motion, 'entering');
  for (let index = 0; index < 24; index++) {
    const home = index < 12, position = index % 12 + 1;
    const clip = `${home ? 'Blue' : 'Red'}_Player_${String(index + 1).padStart(2, '0')}_square.mp4`;
    assert.equal(p.d.getElementById('playerName').textContent, `${home ? 'Home' : 'Guest'} ${position}`);
    assert.equal(p.active().src, 'http://127.0.0.1:5516/user/' + clip);
    assert.equal(p.active().playbackRate, 1.6, 'four-second clips play in 2.5 seconds');
    assert.equal(p.d.querySelectorAll('.is-selected').length, 1);
    assert.equal(p.d.querySelector('.is-selected .row-name').textContent, `${home ? 'Home' : 'Guest'} ${position}`);
    assert.equal(p.d.querySelectorAll('.player-row').length, 12);
    assert.ok([...p.d.querySelectorAll('.player-row')].every(row => row.dataset.key.startsWith(home ? 'home:' : 'guest:')));
    assert.equal(p.d.getElementById('rosterTeamName').textContent, home ? 'Blue Team' : 'Red Team');
    if (index === 11) p.d.getElementById('rosterViewport').scrollTop = 900;
    if (index === 12) assert.equal(p.d.getElementById('rosterViewport').scrollTop, 0, 'new team starts at the top');
    assert.ok(fs.existsSync(path.join(directory, clip)));
    await p.ended();
  }
  assert.equal(p.intro.dataset.motion, 'exiting');
  p.finishExit();
  assert.equal(p.intro.hidden, true);
  assert.equal(p.obs.hidden, true, 'no old roster after completion');
  const plays = p.plays();
  p.update('players', roster()); p.display('playerView'); await flush();
  assert.equal(p.plays(), plays, 'resource updates do not replay a completed sequence');
  p.display('teamView');
  assert.equal(p.d.getElementById('teamPresentation').hidden, false);
  assert.equal(p.obs.hidden, true);
  p.display('playerView'); await flush();
  assert.equal(p.d.getElementById('playerName').textContent, 'Home 1');
  assert.equal(p.intro.hidden, false, 'another scene rearms the sequence');
  assert.equal(p.errors.length, 0);
  p.dom.window.close();
});

test('suppresses the built-in roster while loading, playing, exiting, completed, and empty', async () => {
  const p = page();
  assert.match(p.obs.contentDocument.head.textContent, /#playerBug.*display: none !important/);
  p.display('playerView');
  assert.equal(p.obs.hidden, true, 'no fallback list while waiting for resources');
  p.seed({}); await flush();
  assert.equal(p.obs.hidden, true);
  assert.equal(p.intro.hidden, true);
  p.update('players', roster()); await flush();
  assert.equal(p.obs.hidden, true);
  assert.equal(p.intro.hidden, false);
  p.display('scoreboard', 'playerView', false);
  assert.equal(p.intro.dataset.motion, 'exiting');
  assert.equal(p.obs.hidden, true, 'outgoing player panel closes before the score bar opens');
  p.finishExit();
  assert.equal(p.intro.hidden, true);
  assert.equal(p.obs.hidden, false);
  for (const mode of ['scoreboard', 'teamView', 'eventLogo', 'blackScreen', 'backgroundOnly']) {
    p.display(mode, 'playerView');
    assert.equal(p.obs.hidden, mode !== 'scoreboard', mode);
  }
  p.dom.window.close();
});

test('preloads the next clip and holds the existing frame and selection until the next video is decoded', async () => {
  const p = page(); p.seed(); p.display('scoreboard');
  assert.match(p.videos[0].src, /Blue_Player_01_square.mp4$/);
  assert.match(p.videos[1].src, /Blue_Player_02_square.mp4$/);
  assert.equal(p.plays(), 0, 'preloading does not autoplay hidden clips');
  p.display('playerView'); await flush();
  const first = p.active(), spare = p.videos.find(video => video !== first);
  p.readiness.set(spare, 0);
  first.dispatchEvent(new p.w.Event('ended')); await flush();
  assert.equal(p.active(), first, 'last decoded frame remains visible while waiting');
  assert.equal(p.d.getElementById('playerName').textContent, 'Home 1');
  p.readiness.set(spare, 4);
  spare.dispatchEvent(new p.w.Event('loadeddata')); await flush();
  assert.equal(p.active(), spare);
  assert.equal(first.classList.contains('is-previous'), true, 'old frame remains underneath the crossfade');
  assert.equal(p.d.getElementById('playerName').textContent, 'Home 2');
  p.timer(220);
  assert.match(first.src, /Blue_Player_03_square.mp4$/, 'released buffer preloads the following player');
  p.dom.window.close();
});

test('scene changes cancel pending video loads and stale callbacks cannot reveal a player', async () => {
  const p = page(); p.seed(); p.videos.forEach(video => p.readiness.set(video, 0));
  p.display('playerView'); await flush();
  p.display('scoreboard');
  p.videos.forEach(video => { p.readiness.set(video, 4); video.dispatchEvent(new p.w.Event('loadeddata')); });
  await flush();
  assert.equal(p.intro.hidden, true);
  assert.equal(p.obs.hidden, false);
  assert.equal(p.active(), null);
  p.display('playerView'); await flush();
  assert.equal(p.d.getElementById('playerName').textContent, 'Home 1');
  p.dom.window.close();
});

test('live identity updates preserve playback and cannot insert players into an ongoing sequence', async () => {
  const p = page(), players = roster(); p.seed(players); p.display('playerView'); await flush();
  const video = p.active(), plays = p.plays(); video.currentTime = 2;
  players.homeRoster.players[0].name = 'Alice <img src=x>';
  players.homeRoster.players[0].number = '99';
  players.homeRoster.players.push({ id: 'new', name: 'New Player', number: '44' });
  p.update('players', players);
  p.update('teams', { home: { name: 'Blue <script>', logo: { path: '/api/v2/teams/home/logo', id: 'logo-1' } } });
  p.update('clocks', { formattedGameClock: '09:59' });
  p.display('playerView'); await flush();
  assert.equal(p.plays(), plays);
  assert.equal(video.currentTime, 2);
  assert.equal(p.d.getElementById('playerName').textContent, 'Alice <img src=x>');
  assert.equal(p.d.getElementById('playerName').children.length, 0);
  assert.equal(p.d.getElementById('playerNumber').textContent, '#99');
  assert.equal(p.d.getElementById('teamName').textContent, 'Blue <script>');
  assert.equal(p.d.querySelectorAll('.player-row').length, 12, 'running sequence keeps its current-team roster snapshot');
  assert.match(video.src, /Blue_Player_01_square.mp4$/);
  p.dom.window.close();
});

test('event name replaces the heading and game updates do not restart the current video', async () => {
  const p = page(); p.seed(); p.display('playerView'); await flush();
  const video = p.active(), plays = p.plays(); video.currentTime = 2;
  p.update('game', { eventName: 'Finals <img src=x>' });
  assert.equal(p.d.getElementById('eventName').textContent, 'Finals <img src=x>');
  assert.equal(p.d.getElementById('eventName').children.length, 0);
  assert.equal(p.d.querySelector('.eyebrow'), null);
  assert.equal(p.plays(), plays);
  assert.equal(video.currentTime, 2);
  p.update('game', { eventName: '   ' });
  assert.equal(p.d.getElementById('eventName').parentElement.hidden, true, 'no invented title for an empty event name');
  p.dom.window.close();
});

test('skips players missing either name or number without shifting their original video mapping', async () => {
  const p = page(), players = roster();
  players.homeRoster.players[0].name = '  ';
  players.homeRoster.players[1].number = '';
  players.homeRoster.players[2].name = null;
  players.homeRoster.players[3].number = null;
  players.homeRoster.players[4].number = 0;
  p.seed(players); p.display('playerView'); await flush();
  assert.equal(p.d.querySelectorAll('.player-row').length, 8);
  assert.equal(p.d.getElementById('playerName').textContent, 'Home 5');
  assert.equal(p.d.getElementById('playerNumber').textContent, '#0', 'zero is a valid number');
  assert.match(p.active().src, /Blue_Player_05_square.mp4$/);
  assert.ok([...p.d.querySelectorAll('.row-name')].every(row => row.textContent.trim()));
  assert.ok([...p.d.querySelectorAll('.row-number')].every(row => row.textContent.trim()));
  players.homeRoster.players[4].name = '';
  players.homeRoster.players[5].number = '   ';
  p.update('players', players); await flush();
  assert.equal(p.d.getElementById('playerName').textContent, 'Home 7', 'live blank fields skip current and upcoming incomplete players');
  assert.match(p.active().src, /Blue_Player_07_square.mp4$/);
  assert.equal(p.d.querySelectorAll('.player-row').length, 6);
  p.dom.window.close();
});

test('unavailable media skips safely and a playback stall advances without looping', async () => {
  const p = page(); p.seed(); p.readiness.set(p.videos[0], 0); p.display('playerView'); await flush();
  p.videos[0].dispatchEvent(new p.w.Event('error')); await flush();
  p.readiness.set(p.videos[0], 4); p.videos[0].dispatchEvent(new p.w.Event('loadeddata')); await flush();
  assert.equal(p.d.getElementById('playerName').textContent, 'Home 2');
  p.timer(4000); await flush();
  assert.equal(p.d.getElementById('playerName').textContent, 'Home 3');
  p.dom.window.close();
});

test('reconnecting in the same player scene cannot replay the sequence', async () => {
  const p = page(); p.seed(); p.display('playerView'); await flush();
  p.sockets[0].onclose(); p.finishExit();
  assert.equal(p.obs.hidden, true);
  const plays = p.plays();
  p.timer(1200); p.sockets[1].onopen(); p.seed(); p.display('playerView'); await flush();
  assert.equal(p.plays(), plays);
  assert.equal(p.intro.hidden, true);
  assert.equal(p.obs.hidden, true);
  p.display('eventLogo'); p.display('playerView'); await flush();
  assert.equal(p.intro.hidden, false);
  p.dom.window.close();
});

test('both user URLs retain video asset paths and OBS language', async () => {
  for (const url of ['http://localhost:5516/user?lang=zh', 'http://localhost:5516/user/?lang=zh']) {
    const p = page(url); p.seed(); p.display('playerView'); await flush();
    assert.equal(p.active().src, 'http://localhost:5516/user/Blue_Player_01_square.mp4');
    assert.equal(new URL(p.obs.src).searchParams.get('displayId'), '3');
    assert.equal(new URL(p.obs.src).searchParams.get('lang'), 'zh');
    assert.equal(p.sockets[0].sent.apiVersion, 'v2');
    p.dom.window.close();
  }
});

test('every scene closes before the next opens and rapid switches select only the latest scene', async () => {
  const p = page(); p.seed(); p.display('scoreboard');
  p.display('teamView', 'scoreboard', false);
  assert.equal(p.obs.dataset.motion, 'exiting');
  assert.equal(p.d.getElementById('teamPresentation').hidden, true);
  p.display('eventLogo', 'scoreboard', false);
  assert.equal(p.d.getElementById('eventPresentation').hidden, true);
  p.finishScenes();
  const event = p.d.getElementById('eventPresentation');
  assert.equal(event.hidden, false);
  assert.equal(event.dataset.motion, 'entering');
  assert.equal(p.d.getElementById('presentationEventName').textContent, 'Championship');
  assert.equal(p.d.getElementById('teamPresentation').hidden, true);
  assert.equal(p.obs.hidden, true);
  p.display('teamView', 'scoreboard', false);
  assert.equal(event.dataset.motion, 'exiting');
  p.finishScenes();
  const team = p.d.getElementById('teamPresentation');
  assert.equal(team.hidden, false);
  assert.equal(team.dataset.motion, 'entering');
  assert.equal(p.d.getElementById('presentationHomeName').textContent, 'Blue Team');
  assert.equal(p.d.getElementById('presentationGuestScore'), null, 'Team View has no score display');
  p.update('teams', { home: { name: 'Home <img src=x>', score: 20 }, guest: { name: 'Guests', score: 21 } });
  assert.equal(p.d.getElementById('presentationHomeName').textContent, 'Home <img src=x>');
  assert.equal(p.d.getElementById('presentationHomeName').children.length, 0);
  assert.equal(p.d.querySelectorAll('.profile-score').length, 0, 'live score updates do not add scores to Team View');
  p.display('backgroundOnly', 'scoreboard', false);
  assert.equal(team.dataset.motion, 'exiting');
  p.finishScenes();
  assert.ok([team, event, p.intro, p.obs].every(panel => panel.hidden));
  p.dom.window.close();
});

test('score increases overlay the old score, bonus, and new score; repeats and corrections do not fabricate points', () => {
  const p = page(); p.seed(); p.display('scoreboard');
  const doc = p.obs.contentDocument;
  assert.equal(doc.querySelectorAll('.score-change').length, 0, 'initial score is silent');
  p.update('teams', { home: { name: 'Blue Team', score: 13 }, guest: { name: 'Red Team', score: 12 } });
  const effect = doc.querySelector('.home .score-change');
  assert.equal(effect.querySelector('.score-old').textContent, '10');
  assert.equal(effect.querySelector('.score-delta').textContent, '+3');
  assert.equal(effect.querySelector('.score-new').textContent, '13');
  assert.equal(doc.getElementById('homeScore').textContent, '13');
  p.update('teams', { home: { score: 13 }, guest: { score: 12 } });
  p.update('clocks', { formattedGameClock: '09:59' });
  assert.equal(doc.querySelector('.score-change'), effect, 'same score and clock ticks do not restart the effect');
  p.timer(1100);
  assert.equal(doc.querySelector('.score-change'), null);
  p.update('teams', { home: { score: 13 }, guest: { score: 14 } });
  assert.equal(doc.querySelector('.guest .score-delta').textContent, '+2');
  p.update('teams', { home: { score: 13 }, guest: { score: 12 } });
  assert.equal(doc.querySelector('.score-change'), null, 'score correction cancels a stale bonus');
  p.display('teamView');
  p.update('teams', { home: { score: 16 }, guest: { score: 12 } });
  p.display('scoreboard');
  assert.equal(doc.querySelector('.score-change'), null, 'points from another scene are not replayed');
  p.dom.window.close();
});

test('foul and card messages identify team and player, queue individually, and fade out below the score bar', () => {
  const p = page(), players = roster(); p.seed(players); p.display('scoreboard');
  const toast = p.obs.contentDocument.getElementById('foulToast');
  assert.equal(toast.hidden, true);
  players.homeRoster.players[0].name = 'Alice <img src=x>';
  players.homeRoster.players[0].foulCount = 1;
  p.update('players', players);
  assert.equal(toast.hidden, false);
  assert.equal(toast.textContent, 'Blue Team · #1 Alice <img src=x> — Foul +1 · 1 total');
  assert.equal(toast.children.length, 0);
  assert.equal(toast.dataset.motion, 'entering');
  p.update('players', players);
  players.guestRoster.players[1].cardStatus = 'yellow';
  p.update('players', players);
  assert.match(toast.textContent, /Alice/, 'next event waits for the current toast');
  p.timer(3200);
  assert.equal(toast.dataset.motion, 'exiting');
  p.timer(300);
  assert.equal(toast.textContent, 'Red Team · #2 Guest 2 — Yellow card');
  assert.equal(toast.dataset.kind, 'yellow');
  players.guestRoster.players[1].cardStatus = 'red';
  players.guestRoster.players[1].foulCount = 2;
  p.update('players', players);
  p.timer(3200); p.timer(300);
  assert.equal(toast.textContent, 'Red Team · #2 Guest 2 — Foul +2 · 2 total · Red card');
  assert.equal(toast.dataset.kind, 'red');
  p.timer(3200); p.timer(300);
  assert.equal(toast.hidden, true, 'duplicate snapshots created no extra messages');
  p.dom.window.close();
});

test('existing penalties, reversals, incomplete players, and events in other scenes stay silent', () => {
  const p = page(), players = roster();
  players.homeRoster.players[0].foulCount = 3;
  players.homeRoster.players[0].cardStatus = 'red';
  p.seed(players); p.display('scoreboard');
  const toast = p.obs.contentDocument.getElementById('foulToast');
  assert.equal(toast.hidden, true);
  players.homeRoster.players[0].foulCount = 2;
  players.homeRoster.players[0].cardStatus = 'yellow';
  p.update('players', players);
  assert.equal(toast.hidden, true, 'reversing a penalty is silent');
  players.homeRoster.players[0].name = '';
  players.homeRoster.players[0].foulCount = 4;
  p.update('players', players);
  assert.equal(toast.hidden, true, 'incomplete player is excluded');
  p.display('eventLogo');
  players.guestRoster.players[0].foulCount = 1;
  p.update('players', players);
  p.display('scoreboard'); p.update('players', players);
  assert.equal(toast.hidden, true, 'old events are not replayed after a scene switch');
  p.dom.window.close();
});

test('powered logo expands once per score-bar appearance, holds five seconds, then drops away', () => {
  const p = page(); p.seed(); p.display('scoreboard');
  const logo = p.obs.contentDocument.getElementById('scorePowered');
  assert.equal(logo.hidden, false);
  assert.equal(logo.dataset.motion, 'entering');
  assert.equal(logo.querySelector('img').src, 'http://127.0.0.1:5516/user/powered.png');
  assert.ok(fs.existsSync(path.join(directory, 'powered.png')));
  p.timer(450);
  assert.equal(logo.dataset.motion, 'visible');
  p.timer(5000);
  assert.equal(logo.dataset.motion, 'exiting');
  p.timer(400);
  assert.equal(logo.hidden, true);
  p.update('teams', { home: { name: 'Blue Team', score: 13 }, guest: { name: 'Red Team', score: 12 } });
  p.display('scoreboard');
  assert.equal(logo.hidden, true, 'routine updates do not replay branding');
  p.display('teamView'); p.display('scoreboard');
  assert.equal(logo.hidden, false, 'another score-bar appearance plays the branding again');
  assert.equal(logo.dataset.motion, 'entering');
  p.dom.window.close();
});

test('other visible scenes use the footer logo and closing a scene cancels score-logo timers', async () => {
  const p = page(); p.seed(); p.display('scoreboard'); p.timer(450);
  const scoreLogo = p.obs.contentDocument.getElementById('scorePowered');
  const footer = p.d.getElementById('scenePowered');
  assert.equal(footer.hidden, true);
  p.display('teamView');
  assert.equal(footer.hidden, false);
  assert.equal(footer.dataset.motion, 'entering');
  assert.equal([...p.timers.values()].some(timer => timer.delay === 5000), false, 'old score-logo hold is cancelled');
  p.timer(400);
  assert.equal(scoreLogo.hidden, true);
  p.display('eventLogo');
  assert.equal(footer.hidden, false);
  p.display('playerView'); await flush();
  assert.equal(footer.hidden, false);
  for (let index = 0; index < 24; index++) await p.ended();
  assert.equal(footer.dataset.motion, 'exiting');
  p.finishExit();
  assert.equal(footer.hidden, true, 'completed introductions return to a transparent canvas');
  p.display('blackScreen');
  assert.equal(footer.hidden, true);
  p.display('backgroundOnly');
  assert.equal(footer.hidden, true);
  p.dom.window.close();
});
