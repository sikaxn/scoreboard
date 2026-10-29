# Custom display 3 broadcast page

Open **http://127.0.0.1:5516/user/** in an OBS browser source (1920 × 1080).
On another device, replace `127.0.0.1` with the scoreboard Mac's address.
Enable the app's Web API and custom display 3. Refresh the OBS browser source
when installing an updated page.

Player View, Team View, and Event Logo View use large, centered presentation
panels (up to 1600 × 900). The canvas around them is transparent and the panel
backing is translucent. Every view opens and closes with a fade; the outgoing
view closes before the next opens. Rapid switches select the latest requested
view. Broadcast fades and selector motion stay enabled even when the OBS
browser reports an operating-system preference for reduced motion.

**Player View** plays the introductions once per scene entry:

1. The panel opens with the live event name and the complete home roster.
   Every name fits in the left column at once; no scrolling is needed.
2. A colored selector box slides down the roster. Each selected player's
   square pose video plays on the right, with their name, number, and team.
   Playback speed adjusts each clip to **2.5 seconds**. There is no progress bar.
3. After the home team, the whole list switches to the guest roster.
4. After the final guest, the panel closes and the source stays transparent.
   Switch to another display mode and back to Player View to replay the
   sequence. Routine API updates and reconnecting in the same player scene
   do not replay it.

Two video buffers preload the next clip. The previous decoded frame stays
visible until the next video has decoded a frame, then the videos crossfade.
Names, numbers, and team details update live without restarting a clip. The
sequence takes a roster snapshot when it starts, regardless of the app's
Player View Roster Scope setting. Additions and reordering apply to the next
run. Players missing either a name or a number, including whitespace-only
fields, are skipped. A number of zero is valid. If a field is cleared during
playback, that player is skipped as well. An empty roster waits transparently.

**Team View** shows both teams' names and logos when available, without scores.
**Event Logo View** shows the event logo and name. Logo visibility settings and
the app's display direction are respected. Long names wrap inside the panels.

**Scoreboard** uses the app's `/demo/obs?displayId=3` clock and pause formatting,
with the bar arranged horizontally: one team, the clock, and the other team.
The bar opens outward from the middle and closes inward to the middle.
A score increase overlays the old score, a `+N` badge, and the new score.
Initial values, repeated updates, and score corrections do not generate bonus
animations. New individual fouls and yellow/red cards show a message below the
bar naming the team, player, and foul count/card. Messages queue and fade in
and out; existing penalties and events from other views are not replayed.
The old built-in player, team, and event panels are suppressed.

**Powered logo:** keep `powered.png` beside `index.html`. Whenever the score
bar opens, the logo expands upward above it, holds for five seconds after
expanding, then slides down behind the bar. Score updates do not restart it.
In Player, Team, and Event Logo views, the logo stays at the bottom center of
the canvas, with space reserved beneath the presentation panel. It closes
with the scene and stays hidden on blank views and after a player run finishes.

Black Screen and Background Only close the current overlay and leave the
source transparent. A dropped connection closes the current scene; a player
sequence does not restart in the same player scene after reconnecting. Missing
clips are skipped after at most seven seconds; stalled playback advances safely.

Keep `index.html`, `powered.png`, and all 24 MP4 files together in the app's `CustomWebPage`
folder. The `/user` URL without a trailing slash also works.

Clips map to original full-roster positions, independently of jersey numbers:
home positions 1–12 use `Blue_Player_01_square.mp4` through
`Blue_Player_12_square.mp4`; guest positions 1–12 use
`Red_Player_13_square.mp4` through `Red_Player_24_square.mp4`.
Skipping incomplete players does not shift these mappings. For larger rosters
the clips repeat. Edit `CLIPS` in `index.html` to customize the mapping.

Sequence, scene-transition, score-animation, and foul/card checks:

```sh
node --test tests/web/player-introductions.test.cjs
```
