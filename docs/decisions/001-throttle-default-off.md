# ADR 001: Make `throttle` Work, but Default to `OFF`

**Status:** Accepted (2026-09-26)

## Context

`Sockets.throttle` was documented as how often sockets are checked for incoming data, with the constants `OFF` (every frame), `LOW` (33 ms), `MEDIUM` (66 ms) and `HIGH` (1 s), and a nominal default of `MEDIUM`. The interval was ignored: sockets were checked once per frame whatever the setting. Every app built on dmc-sockets has therefore always run with a check every frame, and its latency was measured that way: in Solar2D a request/response round trip takes one frame, 33 ms at 30 fps (see dmc-websockets' [performance results](https://github.com/dmccuskey/dmc-websockets/blob/master/docs/compliance.md#performance-140)).

Honoring the documented default would have changed that behavior for every app on upgrade:

- A round trip in Solar2D would take about 66 ms instead of 33 ms, since data is noticed only every other frame.
- The Autobahn|Testsuite's 1000-round-trip cases (9.7.x, 9.8.x) take 33 s today; at 66 ms each they would pass their 60 s limit and fail.

dmc-websockets passes its own `throttle` option through to this setting, so the setting can't simply go away.

## Decision

- `throttle` works as documented: `LOW`, `MEDIUM`, `HIGH` or a number of milliseconds spaces out the checks; `OFF` (0) checks every frame.
- The default is `OFF` (`Sockets.DEFAULT`), for sockets created directly and when `dmc_corona.cfg` sets no `throttle_level`. An invalid value also falls back to `OFF`.

Options considered:

- **Implement it as documented, default `MEDIUM`.** Rejected: it doubles round-trip latency for every existing app and fails the Autobahn round-trip cases, for a small saving in work per frame.
- **Remove `throttle`.** Rejected: dmc-websockets sets it on every connection, and apps may set it too; removing it breaks them.

## Consequences

- Apps behave as before: one check per frame, one frame per round trip.
- Apps that want fewer checks, such as ones that rarely receive data and care about per-frame work, can now opt in.
- The documentation's default changed from `MEDIUM` to `OFF`, here and in dmc-websockets.
