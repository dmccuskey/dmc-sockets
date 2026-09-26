# Changelog

## Unreleased

### Fixed

- Large sends on the async socket were cut short: a non-blocking send that wrote only part of the data dropped the rest (roughly anything over 64-256KB). Unsent data is now queued and written on the following frames, and the send callback fires once everything is sent, or with `isError` if the connection fails.
- `throttle` had no effect: sockets were checked every frame whatever the setting. `LOW`, `MEDIUM`, `HIGH` and millisecond values now space out the checks.
- The async socket's `timeout` couldn't be set, and reading it cleared it. It is now a real property (default 6000 ms) and can be passed to `Sockets:create()`.
- `receive( '*l' )` returned lines with a trailing `\r` and only recognized CRLF. Lines now come without their line ending, and a bare LF also ends a line, as in LuaSocket. The same goes for `receiveUntilNewline()`.
- `receiveUntilNewline()` could corrupt or repeat header lines when the headers arrived over several reads.
- Secure connections failed against current servers: `setoption()` was called on the TLS-wrapped socket, which has no such method; no SNI was sent, so servers on shared hosts and CDNs refused the handshake; and TLS 1.0 was forced. Found through [dmc-websockets #6](https://github.com/dmccuskey/dmc-websockets/issues/6).

### Changed

- The default `throttle` is `OFF` (every frame; it was nominally `MEDIUM`), so apps behave as before now that the setting works.

- `ssl_params.protocol` defaults to `'any'` (was `'tlsv1'`) and accepts `'tlsv1_1'`, `'tlsv1_2'` and `'tlsv1_3'`.
- Outside Solar2D, TLS uses plain luasec when the Solar2D plugins aren't available.
- The bundled libraries are updated.

### Added

- Documentation: Quick Start, API reference with known issues, development guide.
- Unit tests (`tests/run_unit.sh`).
