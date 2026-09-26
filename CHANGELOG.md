# Changelog

## Unreleased

### Fixed

- Large sends on the async socket were cut short: a non-blocking send that wrote only part of the data dropped the rest (roughly anything over 64-256KB). Unsent data is now queued and written on the following frames, and the send callback fires once everything is sent, or with `isError` if the connection fails.
- Secure connections failed against current servers: `setoption()` was called on the TLS-wrapped socket, which has no such method; no SNI was sent, so servers on shared hosts and CDNs refused the handshake; and TLS 1.0 was forced. Found through [dmc-websockets #6](https://github.com/dmccuskey/dmc-websockets/issues/6).

### Changed

- `ssl_params.protocol` defaults to `'any'` (was `'tlsv1'`) and accepts `'tlsv1_1'`, `'tlsv1_2'` and `'tlsv1_3'`.
- Outside Solar2D, TLS uses plain luasec when the Solar2D plugins aren't available.
- The bundled libraries are updated.

### Added

- Documentation: Quick Start, API reference with known issues, development guide.
