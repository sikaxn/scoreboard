# Scoreboard

<p align="center">
  <img src="icon.png" alt="Scoreboard app icon" width="160">
</p>

Scoreboard is a SwiftUI scoreboard app for iPad and Mac. It gives an operator a private control board while showing a clean public scoreboard on an external display or through AirPlay.

This project use AI generated contents.

> App Store: [Coming soon](https://apps.apple.com/app/idXXXXXXXXXX)

## Description

Scoreboard turns your iPad or Mac into a flexible, easy-to-control scoreboard for games, practices, tournaments, and debate rounds.

Track scores, clocks, periods, shot clocks, possession, fouls, cards, substitutions, rosters, chess clocks, hockey penalty timers, and debate prep time from one clean control board. Show a full-screen public scoreboard on an external display or through AirPlay while keeping the controls private on your device.

Built-in presets include Simple, Basketball, Volleyball, Soccer, Hockey, Chess, Debate, and Custom Sport modes. Debate supports Public Forum, Lincoln-Douglas, Policy, and custom round formats.

Whether you are running a gym scoreboard, timing a debate round, managing a scrimmage, or keeping a clean public display for spectators, Scoreboard keeps the game organized and visible.

## Full Experience

For the full Scoreboard experience, connect an external display or use AirPlay. This lets you keep scoring controls, rosters, logs, and setup tools on your device while presenting the public scoreboard full-screen for players, judges, or spectators.

## Features

- Real-time score, period, and game clock controls
- Public scoreboard support for external displays and AirPlay
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

- iPad
- Mac

The project is configured as a SwiftUI app with iPadOS and macOS support.

## Build From Source

1. Clone the repository.
2. Open `smartScoreboard/smartScoreboard.xcodeproj` in Xcode.
3. Select the `smartScoreboard` scheme.
4. Choose an iPad simulator, a connected iPad, or Mac as the run destination.
5. Build and run.

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
