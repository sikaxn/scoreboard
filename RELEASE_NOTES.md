# Release Notes

## 1.4

- Added a Keyboard Shortcuts settings page for iPhone, iPad, and Mac operator devices.
- Added configurable hardware-keyboard shortcuts for stable live control board actions, with safe defaults for timer toggle, basic scoring, secondary timer action, home/guest secondary-timer assignment, and player-page navigation.
- Left reset and other higher-risk actions unassigned by default while keeping them configurable through the new settings page.
- Added conflict normalization so each shortcut belongs to one action and destructive actions continue through the existing confirmation flow.

## 1.3

- Added Soccer and Custom countdown injury-time controls with automatic +N minute public display.
- Added a Web API Commentator Dashboard at `/commentator`, backed by a non-blocking current-session `/api/v2/commentator` cache for live timeline, roster alerts, and deterministic talking points.
- Added Custom Display Control for Web API custom pages and Remote Display, with shared display IDs 1-8, ID 0 fallback to the main Display Control, configurable enabled display count, and renamed Custom 1-3 mode labels.
- Expanded Web API v2 and bundled demos for Custom Display Control while keeping the compatible `display.broadcastControl` JSON key; Remote Display clients continue to follow the main display unless individual control is enabled.
- Fixed a real-device iOS settings crash when rendering Custom Sport or Debate setup sections.
- Hardened localization rendering and formatted localized strings to avoid device-only crashes from dynamic SwiftUI localization keys or mismatched format arguments.
- Fixed next-period changes so modes with a standard game clock reset the game clock and injury time while preserving previous-period and custom dual-clock/disabled-clock behavior.

## 1.2

### Feature Added

- Added team pause tracking for Basketball, Volleyball, Hockey, and Custom Sports that enable pauses.
- Added pause allowance setup, live pause controls, public display pause indicators, logs, sounds, Companion events, Remote Display sync, and Web API output.
- Added optional Web API Custom User Page support, served from `/user` and `/user/...` when included by the build setting, with a default Hello World `index.html`.
- Added Files app access on iPhone and iPad for Library, Logs, and Custom User Page files so user-managed files can be edited outside the app.
- Added Finder access on Mac for the Custom User Page folder.
- Added upgrade migration for existing Library, Logs, and Custom User Page files into user-visible storage, with blocking progress for large migrations and cleanup of migrated legacy folders.
- Added a branded 404 page for the Web API server.
- Improved Control Board toolbar access and status visibility for Sound and Bitfocus Companion.
- Expanded sound and Companion event coverage for Debate segments, Debate prep time, side clocks, unassigned Debate timers, and team pause use.
- Improved sound playback responsiveness by preparing test sound effects ahead of use.
- Expanded the Web API with v2 status endpoints, resource-based state output, changed-resource WebSocket updates, and direct image endpoints for backgrounds, team logos, and event logos.
- Updated Web API docs and demo overlays to support v2 state, event logo, team view, player view display modes, and the new 404 and custom page routes.

### Bug Fixed

- Fixed a Debate Companion edge case so side-specific, prep, and unassigned Debate timer events can trigger the correct commands.
- Improved local scoreboard sleep prevention when the local scoreboard view is visible.
- Improved persistence and sync for team pause counters across saved games, public displays, Remote Display, and Web API clients.
- Improved startup behavior so migration UI only appears when files need to move.
- Improved Factory Default behavior so Custom User Page files are cleared and the default page is recreated cleanly.

## 1.1

### Feature Added

- Added Apple TV support as a display-only Remote Display for paired Scoreboard devices.
- Added Remote Display pairing for nearby Apple TV, iPhone, iPad, and Mac devices with live scoreboard sync.
- Added iPhone support with improved compact layouts.
- Added Live Activities and Dynamic Island support for active game timers.
- Added local Web API support with HTTP and WebSocket output for overlays, OBS, and production tools.
- Added Bitfocus Companion integration for triggering production commands from scoreboard events.
- Added full app backup and restore.
- Added roster CSV import and export.
- Added public display modes for black screen, background-only, team view, player view, and event logo.
- Added team logos, event logo, custom display backgrounds, display direction controls, and date/time overlays.
- Expanded Debate tools with Debate Designer, editable segment blocks, templates, prep controls, and dual-clock or no-timer segment support.
- Added Volleyball period-win tracking with best-of-3/best-of-5 formats, period winner actions, automatic score resets, match winner state, and an 8-second serve timer.
- Expanded Custom Sports with optional period-win tracking, serve timer mode, and hockey-style penalty timers.

### Bug Fixed

- Fixed excessive disk writes while timers are running.
- Improved shot clock performance during active games.
- Fixed hockey penalty timer clearing behavior.
- Fixed settings guidance display issues.
- Fixed display direction handling across the control board, external display, Web API, and Remote Display.
- Improved iPhone settings layout and keyboard behavior.
- Improved Remote Display connection and status handling.
- Fixed missing Chinese localization text across Settings, Control Board, logs, and new Volleyball/Custom Sports controls.
- Expanded OS compatibility for supported devices.

## 1.0

Initial App Store release.
