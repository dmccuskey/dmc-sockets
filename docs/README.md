# dmc-sockets Documentation

New here? The [Quick Start](../README.md#quick-start) makes an HTTP request from a Solar2D app in about 10 minutes.

## Start

- [Quick Start](../README.md#quick-start): copy the library in, connect, send and receive

## Use

- [API reference](api.md): creating sockets, the async and plain TCP sockets, TLS settings, configuration, known issues
- [Examples](../examples/): an async HTTP request with a line-by-line reader, and a plain TCP socket with events

## Internals

- [How data arrives](api.md#how-data-arrives): the per-frame poller, and what it means for latency
- [LuaSocket](https://lunarmodules.github.io/luasocket/) and [luasec](https://github.com/lunarmodules/luasec): the libraries underneath

## Contribute

- [Development](development.md): testing, rebuilding the bundled libraries, possible future changes
- [Changelog](../CHANGELOG.md)
- [Issues](https://github.com/dmccuskey/dmc-sockets/issues)

## Project Structure

```text
README.md                   landing page and Quick Start
CHANGELOG.md
LICENSE
docs/                       this documentation
dmc_corona/                 what apps copy
├── dmc_sockets.lua         the socket factory and poller (source)
├── dmc_sockets/            TCP, async TCP and TLS settings (source)
└── lib/dmc_lua/            DMC Lua library (generated copy)
dmc_corona_boot.lua         loader, from dmc-corona-boot (generated copy)
dmc_corona.cfg              library configuration
examples/                   sample apps, each with its own generated dmc_corona/
main.lua                    leftover from dmc-objects; refers to tests that don't exist here
Snakefile                   build rules for the generated copies
```
