const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { JSDOM } = require('jsdom');
const assets = path.resolve(__dirname, '../../smartScoreboard/smartScoreboard/Assets.xcassets');

function page(mode) {
  const timers = new Map(), errors = [];
  let timerID = 0;
  const dom = new JSDOM(fs.readFileSync(path.join(assets, mode === 'obs' ? 'WebAPIOBSDemo.dataset/obs.html' : 'WebAPIScoreboardDemo.dataset/scoreboard.html'), 'utf8'), {
    url: `http://localhost:5516/demo/${mode}`, runScripts: 'dangerously', beforeParse(w) {
      w.WebSocket = class { send() {} close() {} };
      w.setTimeout = (fn, delay) => { timers.set(++timerID, { fn, delay }); return timerID; };
      w.clearTimeout = id => timers.delete(id); w.setInterval = () => 1;
      w.addEventListener('error', event => errors.push(event.error));
    },
  });
  return { dom, w: dom.window, d: dom.window.document, errors,
    timer(delay) { const found = [...timers].find(([, value]) => value.delay === delay); assert.ok(found, `pending ${delay}ms timer`); timers.delete(found[0]); found[1].fn(); },
  };
}
function state() {
  const roster = side => Array.from({ length: 24 }, (_, index) => ({ id: `${side}-${index}`, name: `${side} Player ${index + 1}`, number: String(index), foulCount: index % 4, cardStatus: index === 0 ? 'yellow' : 'none' }));
  return {
    rules: { sport: 'basketball', title: 'Basketball', supportsScore: true, supportsPeriod: true, periodShortTitle: 'Q', supportsTeamFouls: true, supportsSubstitutions: true, supportsPauses: true, supportsShotClock: true, supportsPossession: true },
    teams: { home: { name: 'North', roleLabel: 'HOME', score: 42, teamFouls: 3, substitutionsRemaining: 4, substitutionsAllowed: 6, substitutionsUsed: 2, pausesRemaining: 2, pausesAllowed: 3, pausesUsed: 1, logo: { id: 'home', path: '/home.png' } }, guest: { name: 'South', roleLabel: 'GUEST', score: 38 } },
    game: { period: 3, eventName: 'Championship' }, clocks: { showsGameClock: true, formattedGameClock: '08:24', gameClockSeconds: 504, formattedShotClock: '18.5', shotClockMilliseconds: 18500, formattedHomeChessClock: '05:10', formattedGuestChessClock: '04:23', activeChessClockSide: 'home' }, runtime: { possessionDirection: 'home' },
    display: { viewMode: 'scoreboard', theme: 'night', layout: 'standard', font: 'rounded', backgroundMode: 'blurred', eventLogo: {id:'event',path:'/event.png'} },
    players: { isPlayerTrackingEnabled: true, isPlayerOverlayPaused: false, homeRoster: { players: roster('home') }, guestRoster: { players: roster('guest') }, homeDisplayed: roster('home').slice(0, 5), guestDisplayed: roster('guest').slice(0, 5), lineupOverflowMode: 'fit' },
  };
}

test('scoreboard renders native themes, layouts, numeric fonts, and repeated live updates', () => {
  const p = page('scoreboard');
  try {
    const s = state();
    for (const layout of ['standard', 'arena', 'broadcast', 'venueRoster']) for (const font of ['rounded', 'block', 'dotMatrix', 'eightSegment']) {
      Object.assign(s.display, { layout, font }); p.w.applyState(s); p.w.applyState(s);
      assert.equal(p.d.body.dataset.layout, layout); assert.equal(p.d.body.dataset.font, font); assert.equal(p.d.body.dataset.theme, 'night');
      assert.equal(p.d.getElementById('homeScore').textContent, '42');
      assert.equal(p.d.getElementById('clock').textContent, '08:24');
      assert.equal(p.d.querySelectorAll('#clock svg').length, font === 'eightSegment' ? 1 : 0);
      assert.equal(p.d.querySelectorAll('#homeLineupList .player-row').length, layout === 'venueRoster' ? 24 : 5);
    }
    assert.equal(p.errors.length, 0);
  } finally { p.dom.window.close(); }
});

test('scoreboard honors photo placement, split and blank backgrounds, real date/time, logos, and broadcast IDs', () => {
  const p = page('scoreboard');
  try {
    const s = state();
    Object.assign(s.display, { backgroundMode: 'image', showsDateTime: true, dateTimeFormat: 'dateTime12Hour', showsDateTimeSeconds: false, direction: 'guestLeft', backgroundImage: {id:'photo',path:'blob:https://scores.test/photo',placement:{scale:2.1,offsetX:.2,offsetY:-.4}} });
    p.w.applyState(s);
    assert.equal(p.d.body.dataset.background, 'image'); assert.equal(p.d.body.dataset.reversed, 'true');
    const photo = p.d.getElementById('backgroundPhoto');
    assert.equal(photo.getAttribute('src'), 'blob:https://scores.test/photo');
    assert.equal(photo.style.getPropertyValue('--photo-scale'), '2.1'); assert.equal(photo.style.getPropertyValue('--photo-x'), '10vw');
    assert.equal(p.d.getElementById('dateTime').hidden, false); assert.ok(p.d.getElementById('dateTime').textContent.length > 5);
    Object.assign(s.display, {showsTeamLogos:false, showsEventLogo:false}); p.w.applyState(s);
    assert.ok(p.d.getElementById('homeLogo').classList.contains('hidden')); assert.ok(p.d.getElementById('boardEventLogo').classList.contains('hidden'));
    s.display.viewMode = 'backgroundOnly'; p.w.applyState(s);
    assert.ok(p.d.body.classList.contains('background-only')); assert.equal(p.d.body.classList.contains('blackout'), false);
    s.display.viewMode = 'blackScreen'; p.w.applyState(s); assert.ok(p.d.body.classList.contains('blackout')); assert.equal(p.d.getElementById('dateTime').hidden, true);
    s.display.broadcastControl = {assignments:[{displayID:1,effectiveRenderMode:'teamView'}]}; p.w.applyState(s);
    assert.equal(p.d.body.classList.contains('blackout'), false); assert.equal(p.d.getElementById('teamView').classList.contains('hidden'), false);
    assert.ok(p.d.getElementById('teamViewHomeLogo').classList.contains('hidden'));
  } finally { p.dom.window.close(); }
});

test('sport details support period wins, penalties, scoreless debate, dual clocks, prep, and player overlay pause', () => {
  const p = page('scoreboard');
  try {
    const s = state(); s.rules.supportsPeriodWins = true; s.teams.home.periodsWon = 2; s.rules.supportsHockeyPenalties = true;
    s.teams.home.penaltyTimers = [{playerNumber:'7',playerName:'Alex <img>',remainingSeconds:85}]; p.w.applyState(s);
    assert.equal(p.d.getElementById('homeWins').hidden, false); assert.match(p.d.getElementById('homeWins').textContent, /2/);
    assert.match(p.d.getElementById('homePenalties').textContent, /#7 Alex <img>01:25/); assert.equal(p.d.querySelector('#homePenalties img'), null);
    s.rules.sport = 'chess'; s.rules.usesChessClocks = true; p.w.applyState(s);
    assert.equal(p.d.getElementById('homeChess').hidden, false); assert.equal(p.d.getElementById('homeChess').textContent, '05:10'); assert.ok(p.d.getElementById('homeChess').classList.contains('active'));
    s.rules.sport = 'debate'; s.rules.usesChessClocks = false; s.rules.supportsScore = false;
    s.debate = {segmentTitle:'Cross examination', segmentTimerMode:'dualClock', homeSideLabel:'Affirmative', guestSideLabel:'Negative', speakingSide:'guest', prepTimeEnabled:true, formattedPrepHomeClock:'02:15', formattedPrepGuestClock:'01:20'};
    p.w.applyState(s);
    assert.equal(p.d.getElementById('dualClocks').hidden, false); assert.equal(p.d.getElementById('guestDualLabel').textContent, 'Negative');
    assert.equal(p.d.getElementById('period').textContent, 'Cross examination'); assert.match(p.d.getElementById('homePrep').textContent, /02:15/);
    assert.ok(p.d.getElementById('homeScore').parentElement.classList.contains('hidden'));
    s.players.isPlayerOverlayPaused = true; p.w.applyState(s); assert.equal(p.d.getElementById('homeLineup').hidden, true);
  } finally { p.dom.window.close(); }
});

test('OBS scene transitions select the latest view, preserve two full rosters, and honor logos and direction', () => {
  const p = page('obs');
  try {
    const s = state(); p.w.applyState(s);
    assert.equal(p.d.getElementById('scorebug').dataset.motion, 'entering');
    s.display.viewMode = 'teamView'; p.w.applyState(s); assert.equal(p.d.getElementById('scorebug').dataset.motion, 'exiting');
    s.display.viewMode = 'playerView'; s.display.direction = 'guestLeft'; p.w.applyState(s); p.timer(400);
    assert.ok(p.d.getElementById('teamBug').classList.contains('hidden')); assert.equal(p.d.getElementById('playerBug').classList.contains('hidden'), false);
    assert.equal(p.d.querySelectorAll('#playerBugHomeList .player-row').length, 24); assert.equal(p.d.querySelectorAll('#playerBugGuestList .player-row').length, 24);
    assert.equal(p.d.getElementById('playerBugHome').style.order, '2'); assert.equal(p.d.getElementById('playerEventName').textContent, 'Championship');
    s.display.viewMode = 'teamView'; s.display.showsTeamLogos = false; p.w.applyState(s); p.timer(400);
    assert.ok(p.d.getElementById('teamBugHomeLogo').classList.contains('hidden')); assert.equal(p.d.getElementById('teamEventName').textContent, 'Championship');
    s.display.viewMode = 'backgroundOnly'; p.w.applyState(s); p.timer(400); assert.equal(p.d.getElementById('scenePowered').hidden, true);
    assert.equal(p.errors.length, 0);
  } finally { p.dom.window.close(); }
});

test('OBS announces only new scores, fouls, and cards; routine ticks, corrections, other scenes, and reconnects stay silent', () => {
  const p = page('obs');
  try {
    const s = state(); p.w.applyState(s); assert.equal(p.d.querySelector('.score-change'), null);
    s.teams.home.score += 3; s.players.homeRoster.players[0].foulCount += 1; p.w.applyState(s);
    assert.equal(p.d.querySelector('.score-delta').textContent, '+3'); assert.match(p.d.getElementById('foulToast').textContent, /North · #0 home Player 1 — Foul \+1/);
    const effect = p.d.querySelector('.score-change'); p.w.applyState(s); assert.equal(p.d.querySelector('.score-change'), effect);
    p.timer(1100); s.teams.home.score -= 2; p.w.applyState(s); assert.equal(p.d.querySelector('.score-change'), null);
    s.display.viewMode = 'eventLogo'; p.w.applyState(s); p.timer(400);
    s.teams.home.score += 1; p.w.applyState(s); s.display.viewMode = 'scoreboard'; p.w.applyState(s); p.timer(400); p.w.applyState(s);
    assert.equal(p.d.querySelector('.score-change'), null); assert.equal(p.d.getElementById('foulToast').hidden, true);
    p.w.setConnected(false); p.timer(400); p.w.setConnected(true); p.w.applyState(s); assert.equal(p.d.querySelector('.score-change'), null);
  } finally { p.dom.window.close(); }
});
