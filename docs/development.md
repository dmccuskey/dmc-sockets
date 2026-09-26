# Development

How dmc-sockets is tested, how to rebuild the libraries it bundles, the decisions behind it, and where it could go next.

## Testing

Unit tests cover reading (line, count and read-all modes, `receiveUntilNewline()` with headers split across reads), `timeout` and `throttle`. They run in plain Lua 5.1, without Solar2D, and need `luasocket` and `dkjson`:

```sh
tests/run_unit.sh
```

Expected output ends with:

```text
  14 passed, 0 failed, 0 error(s), 0 skipped.
```

Network behavior is exercised through [dmc-websockets](https://github.com/dmccuskey/dmc-websockets), which runs on dmc-sockets:

- the Autobahn|Testsuite, 301 cases including 16MB messages and 1000-message bursts, headless and in the Solar2D Simulator (see dmc-websockets' [compliance page](https://github.com/dmccuskey/dmc-websockets/blob/master/docs/compliance.md));
- `wss://` echo checks against public servers, which cover TLS, SNI and the negotiated TLS version.

After changing dmc-sockets, copy the changed files into a dmc-websockets checkout (or rebuild it, below) and run its tests. Don't add this repository's `dmc_corona/` to `LUA_PATH` instead: the shared libraries would then load twice under different names, and errors from one copy aren't recognized by the other.

The [examples](../examples/) are a quick manual check in the Simulator. `dmc-sockets-basic` also runs in plain Lua with [lua-corovel](https://github.com/dmccuskey/lua-corovel); `dmc-sockets-asynctcp` animates a square and needs Solar2D.

## Bundled Libraries

`dmc_corona/` holds copies of the libraries dmc-sockets uses, so an app only has to copy one folder:

| Code | Lives in |
|---|---|
| `dmc_corona/dmc_sockets*` | this repository (the source) |
| `dmc_corona/lib/dmc_lua/` | [DMC-Lua-Library](https://github.com/dmccuskey/DMC-Lua-Library) |
| `dmc_corona_boot.lua` | [dmc-corona-boot](https://github.com/dmccuskey/dmc-corona-boot) |

The copies are generated with [Snakemake](https://snakemake.readthedocs.io/) (version 7), from the other repositories checked out beside this one, using DMC-Corona-Library's shared rules:

```sh
snakemake --cores 1 --forceall build_all
```

The copies come from the sibling checkouts as they are on disk, on whatever branch each has checked out. Libraries that bundle dmc-sockets (dmc-websockets, dmc-netstream, dmc-wamp, DMC-Corona-Library) need rebuilding after a change here.

## Decisions

Architecture decision records, in [decisions/](decisions/):

- [ADR 001: Make `throttle` work, but default to `OFF`](decisions/001-throttle-default-off.md)

## Branches

Changes go on a short-lived branch (`fix/...`, `feat/...`, `docs/...`) and reach `master` once tested.

## Possible Future Changes

These are ideas, not plans. Each needs discussion and a concrete use case before it is worked on; decided work goes in [GitHub issues](https://github.com/dmccuskey/dmc-sockets/issues).

- **Retry on TLS `wantread` during sends,** instead of failing the connection.
- **Non-blocking TLS handshake:** step `dohandshake()` across frames like the TCP connect, so a slow handshake doesn't freeze the app.
- **Report failed connects consistently:** today a TLS failure sets `isError` but leaves `status` as `CONNECTED`.
- **Network tests of its own:** a headless connect/send/receive test against a local server, including TLS.
- **Tidy the repository:** replace the leftover `main.lua` (it runs dmc-objects' tests) with something useful, e.g. the basic example.
- **UDP sockets.**
