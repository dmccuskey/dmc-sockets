# dmc-sockets

Non-blocking TCP sockets for Solar2D (formerly Corona SDK) apps: your code gets callbacks and events instead of polling, and connections can use TLS.

Connect, send and receive without freezing the app:

```lua
local Sockets = require 'dmc_corona.dmc_sockets'

local sock = Sockets:create( Sockets.ATCP )

sock:connect( 'example.com', 80, {
	onConnect=function( event )
		if event.status == sock.CONNECTED then
			sock:send( 'GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n' )
		end
	end,
	onData=function( event )
		sock:receive( '*a', function( result ) print( result.data ) end )
	end,
} )
```

## Features

- Callback-based async TCP sockets: connect, send and receive without blocking the frame
- Async sends of any size: data the network doesn't take right away is written on the following frames
- TLS (`secure = true`), with SNI and the TLS version negotiated, via Solar2D's OpenSSL plugin or luasec
- Line-oriented reads (`'*l'`, and `receiveUntilNewline()` for HTTP-style headers), fixed-size and read-all reads
- One shared poller for all sockets: a round trip costs about one frame
- A simpler event-based TCP socket for blocking connects
- Pure Lua on top of LuaSocket, MIT licensed
- The transport under [dmc-websockets](https://github.com/dmccuskey/dmc-websockets), which passes the Autobahn|Testsuite with it

## Quick Start

The following code will get you up and running in about 10 minutes in the Solar2D Simulator on macOS or Windows. It makes an app that sends an HTTP request and prints the response's status line.

Prerequisites: the [Solar2D](https://solar2d.com/) Simulator and a copy of this repository (`git clone https://github.com/dmccuskey/dmc-sockets.git`, or download the ZIP from GitHub).

1. **Copy the library into your project.** From this repository, copy `dmc_corona/`, `dmc_corona_boot.lua` and `dmc_corona.cfg` into your project, at the root level of the project folder.

2. **Make a request.** Put this in `main.lua`:

   ```lua
   local Sockets = require 'dmc_corona.dmc_sockets'

   local sock = Sockets:create( Sockets.ATCP )

   local function onData( event )
   	sock:receive( '*a', function( result )
   		print( 'received ' .. #result.data .. ' bytes:' )
   		print( result.data:match( '^[^\r\n]*' ) ) -- the HTTP status line
   	end )
   end

   local function onConnect( event )
   	if event.isError then
   		print( 'connection failed:', event.emsg )
   	elseif event.status == sock.CONNECTED then
   		print( 'connected' )
   		sock:send( 'GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n' )
   	end
   end

   sock:connect( 'example.com', 80, { onConnect=onConnect, onData=onData } )
   ```

3. **Run it** in the Simulator. The console shows:

   ```text
   connected
   received 868 bytes:
   HTTP/1.1 200 OK
   ```

   The byte count depends on the server's response, and a large response can arrive in several pieces, each printed separately. If `connected` never appears, check the computer's network connection.

   **Going further:** for TLS, set `sock.secure = true`, connect to port 443, and add Solar2D's OpenSSL plugin to `build.settings` (`plugins = { ["plugin.openssl"] = { publisherId = "com.coronalabs" } }`). Android apps also need the `INTERNET` permission. Reading line by line or in fixed sizes, and error handling, are in the [API reference](docs/api.md).

**Updating:** copy the same files again from a newer version of this repository. The [changelog](CHANGELOG.md) lists what changed.

## Documentation

- [API reference](docs/api.md): creating sockets, the async and plain TCP sockets, TLS settings, configuration, known issues
- [Development](docs/development.md): testing, rebuilding the bundled libraries, possible future changes

Everything else is on the [documentation home](docs/README.md).

## License

MIT, see [LICENSE](LICENSE). The bundled DMC libraries in `dmc_corona/` are MIT licensed too.
