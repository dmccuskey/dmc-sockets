# API Reference

Load the library with:

```lua
local Sockets = require 'dmc_corona.dmc_sockets'
```

`Sockets` is a single shared object that creates sockets and watches them for incoming data, once per frame, for the whole app.

| Item | Kind | Summary |
|---|---|---|
| [`Sockets:create()`](#create) | function | Create an async or a plain TCP socket |
| [Async TCP socket](#async-tcp-socket) | object | Callback-based socket: connect, send and receive without blocking (recommended) |
| [TCP socket](#tcp-socket) | object | Event-based socket with a blocking connect and a read buffer |
| [TLS settings](#tls-settings) | table | `ssl_params` for secure connections |
| [Sockets settings](#sockets-settings) | properties | `check_reads`, `check_writes`, `throttle` |
| [Configuration](#configuration) | file | The same settings in `dmc_corona.cfg` |
| [Known issues](#known-issues) | | Behavior that differs from what the API suggests |

## create()

```lua
local sock = Sockets:create( Sockets.ATCP )                      -- async TCP
local sock = Sockets:create( Sockets.ATCP, { ssl_params={} } )   -- async TCP over TLS
local sock = Sockets:create( Sockets.TCP )                       -- plain TCP
```

| Type | Creates |
|---|---|
| `Sockets.ATCP` | an [async TCP socket](#async-tcp-socket) |
| `Sockets.TCP` | a [TCP socket](#tcp-socket) |

Any other type raises an error. UDP is not implemented.

## Sockets Settings

Properties of `Sockets`, shared by all sockets. They can also be set in [`dmc_corona.cfg`](#configuration).

| Property | Default | Description |
|---|---|---|
| `Sockets.check_reads` | `true` | Watch sockets for incoming data. Setting it to `false` stops all reads |
| `Sockets.check_writes` | `false` | Watch sockets for write readiness (not used yet) |
| `Sockets.throttle` | `Sockets.MEDIUM` | Meant to set how often sockets are checked; see [known issues](#known-issues) |

### How Data Arrives

LuaSocket, which dmc-sockets is built on, is non-blocking but has no callbacks. dmc-sockets therefore checks all of its sockets with `socket.select()` on every frame (`enterFrame`) and turns readable sockets into events. Two consequences:

- The app never blocks waiting for data, and animations keep running.
- Data is noticed at the next frame: a request/response round trip takes about one frame (33 ms at 30 fps, 16 ms at 60 fps). Raise the app's frame rate in `config.lua` for lower latency.

## Async TCP Socket

Created with `Sockets:create( Sockets.ATCP )`. Everything happens through callbacks. Connecting, sending and receiving don't block; the only exception is the TLS handshake of a secure connection, which blocks briefly.

```lua
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

### connect()

```lua
sock:connect( host, port, { onConnect=function, onData=function } )
```

Starts connecting and returns right away. If [`secure`](#secure) is `true`, the TLS handshake follows the TCP connection, with the host name sent for SNI; the handshake itself blocks until it completes.

`onConnect( event )` is called when the connection opens, when it fails, and when it closes (by either side):

| Field | Value |
|---|---|
| `event.type` | `sock.CONNECT` |
| `event.status` | `sock.CONNECTED`, `sock.NOT_CONNECTED` (failed or timed out) or `sock.CLOSED` |
| `event.isError` | `true` if the TLS setup failed (check this first: `status` can still be `CONNECTED`) |
| `event.emsg` | error message, e.g. `'timeout'` |

`onData( event )` is called when received data is waiting to be read. `event.bytes` is how many bytes are buffered. Read them with [`receive()`](#receive). The data from one response can arrive over several `onData` calls.

### send()

```lua
sock:send( data, function( event ) ... end )
```

Queues `data` (a string) and starts writing it. Whatever the network doesn't accept right away is written on the following frames, so large sends work without blocking. The optional callback is called once all of the data has been sent (`event` is empty), or with `event.isError` and `event.emsg` if the connection fails first.

### receive()

```lua
sock:receive( option, function( event ) ... end )
```

Takes data from the socket's buffer and passes it to the callback as `event.data`:

| `option` | Result |
|---|---|
| `'*a'` | everything buffered so far, possibly `''` |
| a number `n` | exactly `n` bytes, if that many are buffered; otherwise the callback is not called |
| `'*l'` | the next line (see [known issues](#known-issues)); waits for it to arrive, up to the socket's timeout (6 seconds), then calls back with `event.emsg = 'timeout'` |

### receiveUntilNewline()

```lua
sock:receiveUntilNewline( function( event ) ... end )
```

Collects lines until an empty line, as at the end of HTTP headers, then calls back with `event.data`, a list of the lines (the last one is `''`; the others keep a trailing `\r`, see [known issues](#known-issues)). Waits up to the socket's timeout; on timeout, the lines read so far go back into the buffer and `event.emsg` is `'timeout'`.

### close()

Closes the connection and drops anything still waiting to be sent. `onConnect` is called with `status == sock.CLOSED`.

### secure

`true` to use TLS. Set it before `connect()`. Creating the socket with `ssl_params` also makes it secure; set `sock.secure = false` afterwards to connect without TLS. In Solar2D, TLS needs `plugin.openssl` in `build.settings`; outside Solar2D it uses luasec.

### ssl_params

The [TLS settings](#tls-settings) for a secure connection, as a table.

### Other Members

Async sockets also have the TCP socket's [`status`](#status), [`buffer_size`](#buffer_size), [`clearBuffer()`](#clearbuffer), [`unreceive()`](#unreceive), [`getstats()`](#getstats) and [`reconnect()`](#reconnect).

## TCP Socket

Created with `Sockets:create( Sockets.TCP )`. It reports through events, and `connect()` **blocks** until the connection is made or fails. After that, reads are non-blocking. There is no TLS support; use the async socket for that.

```lua
local sock = Sockets:create( Sockets.TCP )

sock:addEventListener( sock.EVENT, function( event )
	if event.type == sock.CONNECT and event.status == sock.CONNECTED then
		sock:send( 'GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n' )
	elseif event.type == sock.READ then
		print( sock:receive( '*a' ) )
	end
end )

sock:connect( 'example.com', 80 )
```

### Events

Listen for `sock.EVENT`:

| `event.type` | When | Fields |
|---|---|---|
| `sock.CONNECT` | The connection opened, failed or closed | `event.status`: `sock.CONNECTED`, `sock.NOT_CONNECTED` or `sock.CLOSED` |
| `sock.READ` | Received data is waiting in the buffer | `event.bytes`: bytes buffered |

### connect()

`sock:connect( host, port )` connects, blocking until done, then dispatches `CONNECT`.

### send()

`sock:send( data )` passes straight to LuaSocket and returns its results (`last_byte_sent`, or `nil, error, last_byte_sent`). The socket is non-blocking, so a large send can be partial; send the rest yourself, or use the async socket, which does.

### receive()

`sock:receive( option )` returns data from the buffer, or `nil` if there isn't enough:

| `option` | Returns |
|---|---|
| `'*a'` | everything buffered, possibly `''` |
| a number `n` | `n` bytes, or `nil` if fewer are buffered |
| `'*l'` | the next line ending in CRLF (see [known issues](#known-issues)), or `nil` |

### unreceive()

`sock:unreceive( data )` puts `data` back at the front of the buffer, for when you read more than you could use.

### getstats()

Returns LuaSocket's `getstats()` for the connection: bytes received, bytes sent, and the socket's age in seconds.

### clearBuffer()

Empties the read buffer.

### reconnect()

Connects again to the same host and port. The async socket takes the same options table as `connect()`.

### close()

Closes the connection and dispatches `CONNECT` with `status == sock.CLOSED`.

### status

`sock.NO_SOCKET`, `sock.NOT_CONNECTED`, `sock.CONNECTED` or `sock.CLOSED`.

### buffer_size

Bytes waiting in the read buffer.

## TLS Settings

`ssl_params` is passed to luasec, or Solar2D's OpenSSL plugin:

| Field | Default | Values |
|---|---|---|
| `protocol` | `'any'` | `'any'` negotiates the highest version both sides support. `'tlsv1_3'`, `'tlsv1_2'`, `'tlsv1_1'`, `'tlsv1'` and `'sslv3'` force one version; most servers refuse TLS 1.0 and older |
| `verify` | `'none'` | `'none'` or `'peer'` |
| `mode` | `'client'` | `'client'` |
| `options` | `'all'` | `'all'` |

The constants are also available as `SSLParams.ANY`, `SSLParams.TLS_V1_2` and so on, from `require 'dmc_corona.dmc_sockets.ssl_params'`.

`verify='none'` means the server's certificate is not checked: the connection is encrypted, but not protected against someone impersonating the server.

## Configuration

The [Sockets settings](#sockets-settings) can also go in a `[DMC_SOCKETS]` section of `dmc_corona.cfg`:

| Option | Default | Description |
|---|---|---|
| `check_reads` | `true` | Watch sockets for incoming data. Turning it off stops all reads |
| `check_writes` | `false` | Watch sockets for write readiness (not used yet) |
| `throttle_level` | `66` | See [known issues](#known-issues) |

## Known Issues

- **`throttle` has no effect.** `Sockets.throttle` (`Sockets.OFF`, `LOW`, `MEDIUM`, `HIGH`) and `throttle_level` are meant to set how often sockets are checked, but they are checked every frame whatever the value.
- **The timeout can't be changed.** Connecting and `'*l'` reads time out after 6 seconds. Reading `sock.timeout` clears the timeout by mistake, so don't read it.
- **`'*l'` keeps a trailing `\r`** and only recognizes CRLF line endings, unlike LuaSocket's `'*l'`, which strips the line ending and also accepts a bare LF. The lines from `receiveUntilNewline()` keep it too.
- **TLS errors after connecting:** during a send, a TLS connection can ask to read first (`wantread`); this is treated as a failed connection rather than retried. It is rare in practice.
- **UDP** is not implemented.

Fixes are listed under [Possible Future Changes](development.md#possible-future-changes).
