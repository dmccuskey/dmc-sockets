--====================================================================--
-- tests/dmc_sockets_spec.lua
--
-- Unit tests for dmc-sockets, using Luna Test.
-- Run with tests/run_unit.sh
--====================================================================--


module(..., package.seeall)

package.path = './dmc_corona/?.lua;./dmc_corona/lib/dmc_lua/?.lua;' .. package.path



--====================================================================--
--== Setup


local Sockets

function suite_setup()
	require 'dmc_corona_boot'
	Sockets = require 'dmc_corona.dmc_sockets'
end

local function tcpWithBuffer( data )
	local sock = Sockets:create( Sockets.TCP )
	sock._buffer = data
	return sock
end

local function atcpWithBuffer( data )
	local sock = Sockets:create( Sockets.ATCP )
	sock._buffer = data
	return sock
end



--====================================================================--
--== receive()


function test_lineStripsCRLF()
	local sock = tcpWithBuffer( 'HTTP/1.1 200 OK\r\nHost: x\r\n' )
	assert_equal( 'HTTP/1.1 200 OK', sock:receive( '*l' ) )
	assert_equal( 'Host: x', sock:receive( '*l' ) )
	assert_equal( '', sock._buffer )
end

function test_lineAcceptsBareLF()
	local sock = tcpWithBuffer( 'one\ntwo\r\n' )
	assert_equal( 'one', sock:receive( '*l' ) )
	assert_equal( 'two', sock:receive( '*l' ) )
end

function test_blankLineIsEmpty()
	local sock = tcpWithBuffer( '\r\nbody' )
	assert_equal( '', sock:receive( '*l' ) )
	assert_equal( 'body', sock._buffer )
end

function test_incompleteLineStaysBuffered()
	local sock = tcpWithBuffer( 'no line end yet' )
	assert_nil( sock:receive( '*l' ) )
	assert_equal( 'no line end yet', sock._buffer )
end

function test_receiveCountAndAll()
	local sock = tcpWithBuffer( 'abcdef' )
	assert_nil( sock:receive( 10 ) )
	assert_equal( 'abc', sock:receive( 3 ) )
	assert_equal( 'def', sock:receive( '*a' ) )
	assert_equal( '', sock:receive( '*a' ) )
end

function test_unreceivePutsDataFirst()
	local sock = tcpWithBuffer( 'world' )
	sock:unreceive( 'hello ' )
	assert_equal( 'hello world', sock:receive( '*a' ) )
end



--====================================================================--
--== receiveUntilNewline()


function test_headersCompleteCallsBack()
	local sock = atcpWithBuffer( 'A: 1\r\nB: 2\r\n\r\nbody' )
	local lines
	sock:receiveUntilNewline( function( e ) lines = e.data end )
	assert_table( lines )
	assert_equal( 3, #lines )
	assert_equal( 'A: 1', lines[1] )
	assert_equal( 'B: 2', lines[2] )
	assert_equal( '', lines[3] )
	assert_equal( 'body', sock._buffer )
end

function test_headersSplitAcrossReads()
	local sock = atcpWithBuffer( 'A: 1\r\nB: 2' )
	local lines
	sock:receiveUntilNewline( function( e ) lines = e.data end )
	assert_nil( lines )
	-- the partial headers are put back exactly as they arrived
	assert_equal( 'A: 1\r\nB: 2', sock._buffer )

	-- the rest arrives; the waiting reader finishes, without duplicates
	sock._buffer = sock._buffer .. '\r\n\r\n'
	sock:_processCoroutineQueue()
	assert_table( lines )
	assert_equal( 3, #lines )
	assert_equal( 'A: 1', lines[1] )
	assert_equal( 'B: 2', lines[2] )
	assert_equal( '', lines[3] )
end



--====================================================================--
--== timeout


function test_timeoutDefault()
	local sock = Sockets:create( Sockets.ATCP )
	assert_equal( 6000, sock.timeout )
	-- reading it doesn't change it
	assert_equal( 6000, sock.timeout )
end

function test_timeoutSet()
	local sock = Sockets:create( Sockets.ATCP )
	sock.timeout = 2000
	assert_equal( 2000, sock.timeout )
	assert_equal( 500, Sockets:create( Sockets.ATCP, { timeout=500 } ).timeout )
end

function test_timeoutRejectsBadValues()
	local sock = Sockets:create( Sockets.ATCP )
	assert_error( function() sock.timeout = 0 end )
	assert_error( function() sock.timeout = 'soon' end )
	assert_equal( 6000, sock.timeout )
end



--====================================================================--
--== throttle


-- run the socket check handler at given times, count the checks
local function countChecks( throttle, times )
	local clock = 0
	local getTimer = system.getTimer
	system.getTimer = function() return clock end
	local count = 0
	Sockets._checkConnections = function() count = count + 1 end

	Sockets.throttle = throttle
	for _, t in ipairs( times ) do
		clock = t
		Sockets._socketCheck_handler( {} )
	end

	Sockets._checkConnections = nil -- back to the class method
	system.getTimer = getTimer
	Sockets.throttle = Sockets.OFF
	return count
end

function test_throttleDefaultsToOff()
	assert_equal( Sockets.OFF, Sockets.throttle )
end

function test_throttleOffChecksEveryFrame()
	assert_equal( 5, countChecks( Sockets.OFF, { 16, 33, 50, 66, 83 } ) )
end

function test_throttleSpacesChecks()
	-- MEDIUM is 66 ms: frames every ~17 ms give a check every 4th frame
	local frames = {}
	for i = 1, 12 do frames[i] = i*17 end
	assert_equal( 3, countChecks( Sockets.MEDIUM, frames ) )
end



--====================================================================--
--== send() and TLS


-- a stand-in for a raw socket: send() returns the next queued result
local function fakeSocket( results )
	local fake = { closed=false, sent=0 }
	function fake:send( data, i )
		local r = table.remove( results, 1 ) or { #data }
		return r[1], r[2], r[3]
	end
	function fake:close() self.closed = true end
	return fake
end

function test_sendRetriesOnWantread()
	local sock = Sockets:create( Sockets.ATCP )
	-- TLS wants to read first, then the rest goes out
	sock._socket = fakeSocket( { { nil, 'wantread', 3 }, { 10 } } )
	local evt
	sock:send( '0123456789', function( e ) evt = e end )
	assert_nil( evt, "no callback while waiting" )
	assert_equal( 1, #sock._write_queue )
	assert_equal( 4, sock._write_queue[1].index )

	sock:_processWriteQueue()
	assert_table( evt )
	assert_nil( evt.isError )
	assert_equal( 0, #sock._write_queue )
	sock._socket = nil
end

function test_sendFailsOnError()
	local sock = Sockets:create( Sockets.ATCP )
	sock._socket = fakeSocket( { { nil, 'closed', 0 } } )
	local evt
	sock:send( 'data', function( e ) evt = e end )
	assert_true( evt.isError )
	assert_equal( 'closed', evt.emsg )
	sock._socket = nil
end

function test_failedTLSSetupIsNotConnected()
	local sock = Sockets:create( Sockets.ATCP )
	local fake = fakeSocket( {} )
	sock._socket = fake
	sock._status = sock.CONNECTED
	local got
	sock._onConnect = function( e ) got = e end

	sock:_failSecureConnect( {}, 'handshake failed' )

	assert_true( fake.closed )
	assert_true( got.isError )
	assert_equal( sock.NOT_CONNECTED, got.status )
	assert_equal( 'handshake failed', got.emsg )
	-- no socket left, so the next connect() makes a new one
	assert_nil( sock._socket )
	assert_equal( sock.NO_SOCKET, sock._status )
end

function test_closeWithoutSocket()
	local sock = Sockets:create( Sockets.ATCP )
	sock._socket = fakeSocket( {} )
	sock:_failSecureConnect( {}, 'handshake failed' )
	sock:close() -- no error
	assert_equal( sock.NO_SOCKET, sock._status )
end
