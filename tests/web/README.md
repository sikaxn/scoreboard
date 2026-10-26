# Web demo tests

These Node tests exercise the app's actual control, scoreboard, OBS, and
commentator HTML in jsdom. They cover command payloads, connection state, pause
controls, logos, display modes, localization, and v2 updates.

From the repository root, with Node 18 or later:

```sh
npm ci --prefix tests/web
npm test --prefix tests/web
```

Or run `npm ci` and `npm test` from this directory. Dependencies are pinned in
`package-lock.json`. The tests stub network requests and browser timers; the
disconnect test advances its clock explicitly past the connection grace period.

Swift unit and HTTP integration tests run through the Xcode test target. See
the [main testing guide](../../docs/testing.md).
