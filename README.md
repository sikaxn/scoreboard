# Scoreboard

<p align="center">
  <img src="icon.png" alt="Scoreboard app icon" width="160">
</p>

Scoreboard is a SwiftUI scoreboard app for iPhone, iPad, Mac, and Apple TV. iPhone, iPad, and Mac include the operator controls; Apple TV is a display-only Remote Display for showing a live scoreboard from a paired Scoreboard device.

This project use AI generated contents.

> App Store: [Link](https://apps.apple.com/us/app/smart-scoreboard/id6776096875)

## Description

Scoreboard turns your iPhone, iPad, or Mac into a flexible, easy-to-control scoreboard for games, practices, tournaments, and debate rounds.

Track scores, clocks, periods, shot clocks, possession, fouls, cards, substitutions, rosters, soccer injury time, chess clocks, hockey penalty timers, and debate prep time from one clean control board. Show a full-screen public scoreboard on an external display, through AirPlay, or on one or more paired Remote Display devices while keeping the controls private on the operator device.

Built-in presets include Simple, Basketball, Volleyball, Soccer, Hockey, Chess, Debate, and Custom Sport modes. Debate supports Public Forum, Lincoln-Douglas, Policy, and custom round formats.

Apple TV can be used in two ways. You can AirPlay from the operator device to Apple TV without installing the Apple TV app, because AirPlay is treated like an external display. Or you can install Scoreboard on Apple TV and use it as a Remote Display. Apple TV Remote Display is display-only: it does not run the operator board, edit game setup, manage files, or control the score. Use an iPhone, iPad, or Mac to run the game, then pair Apple TV to show the live public scoreboard.

Whether you are running a gym scoreboard, timing a debate round, managing a scrimmage, or keeping a clean public display for spectators, Scoreboard keeps the game organized and visible.

## Full Experience

For the full Scoreboard experience, connect an external display, use AirPlay, or pair Remote Display devices. AirPlay works with Apple TV without installing the app on Apple TV. Remote Display is useful when you want nearby Apple devices, including multiple displays, to receive synced scoreboard updates from the same operator device.

## Features

- Real-time score, period, and game clock controls
- Soccer and Custom countdown injury-time controls with public +N minute display
- Public scoreboard support for external displays and AirPlay, including Apple TV AirPlay without installing the tvOS app
- Apple TV, iPhone, iPad, and Mac Remote Display pairing with live scoreboard sync across multiple displays
- Built-in modes for Simple, Basketball, Volleyball, Soccer, Hockey, Chess, and Debate
- Custom sport mode with configurable periods, clocks, score steps, possession, players, fouls, cards, and substitutions
- Shot clock controls for supported sports
- Chess clock presets for bullet, blitz, rapid, and classical play
- Debate timers for Public Forum, Lincoln-Douglas, Policy, and custom formats
- Hockey penalty timers
- Player roster and active lineup tracking
- Team fouls, player fouls, cards, substitutions, and possession tracking where supported
- Theme options for different lighting and presentation needs
- Configurable event sounds for clocks, alerts, fouls, cards, substitutions, and score changes
- Save, import, export, and autosave game files
- Event logs with export support

## Supported Platforms

- iPhone
- iPad
- Mac
- Apple TV (Remote Display only)

The iPhone, iPad, and Mac app includes the operator interface and can also be switched into Remote Display mode from Settings. Apple TV AirPlay does not require the Scoreboard Apple TV app. If the Apple TV app is installed, it always runs as a Remote Display only; it is for showing the scoreboard, not controlling it. Remote Display uses Network Framework Bonjour pairing, not the Web API, and can sync more than one display device from the same operator device. The operator can choose same Wi-Fi/LAN only or allow Apple peer-to-peer Wi-Fi for nearby devices.

## Build From Source

1. Clone the repository.
2. Open `smartScoreboard/smartScoreboard.xcodeproj` in Xcode.
3. Select the `smartScoreboard` scheme.
4. Choose an iPhone simulator, iPad simulator, connected iPhone or iPad, Mac, or Apple TV simulator as the run destination.
5. Build and run.

## Localization Notes

- Use the local wrapper functions (`localizedAppText`, `localizedAppFormat`, and the matching store/display wrappers) instead of raw `Text(LocalizedStringKey(...))` or direct localized `String(format:)` calls.
- Treat runtime strings, user-entered names, generated titles, and already-formatted strings as resolved text. Localize them first, then render with `Text(verbatim:)` so SwiftUI does not reinterpret them as localization keys during view rendering.
- Keep `Localizable.xcstrings` format placeholders type-compatible across languages. `%1$@` positional placeholders are fine, but the argument count and placeholder type must still match the source string.
- The top-level `version` field in `Localizable.xcstrings` is the string-catalog schema version, not the app release version.

## Project Structure

- `smartScoreboard/smartScoreboard/ContentView.swift` - main operator interface and setup flow
- `smartScoreboard/smartScoreboard/ExternalScoreboardView.swift` - public scoreboard display
- `smartScoreboard/smartScoreboard/ScoreboardStore.swift` - app state and scoring logic
- `smartScoreboard/smartScoreboard/SportType.swift` - sport presets and rule capabilities
- `smartScoreboard/smartScoreboard/DebateModels.swift` - debate formats and timing segments
- `smartScoreboard/smartScoreboard/ScoreboardGameDocument.swift` - saved game file format
- `smartScoreboard/smartScoreboard/ScoreboardLogging.swift` - event log storage and export
- `smartScoreboard/smartScoreboard/BuzzerPlayer.swift` - generated event sounds
- `smartScoreboard/smartScoreboard/ScoreboardTheme.swift` - app and scoreboard themes

## File Types

Scoreboard uses custom JSON-backed document types:

- `.scoreboardgame` for saved game states
- `.scoreboardlog` for exported log sessions

## License

This project is licensed under the GNU General Public License v3.0. See [LICENSE.md](LICENSE.md) for details.
