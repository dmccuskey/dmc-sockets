#!/bin/sh
#
# Run the lunatest unit specs with plain Lua 5.1.
#
# usage: tests/run_unit.sh
#   override the interpreter with LUA=

set -e

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
LUA=${LUA:-$ROOT/../tools/lua51/bin/lua}

cd "$ROOT"
LUA_PATH="$ROOT/?.lua;$HERE/?.lua;$($LUA -e 'io.write(package.path)')"
LUA_CPATH="$($LUA -e 'io.write(package.cpath)')"
export LUA_PATH LUA_CPATH

# stand-ins for the Solar2D globals the library touches: dmc_corona_boot
# needs json and system.pathForFile; the sockets use Runtime listeners,
# system.getTimer and timers (the specs replace getTimer to control time)
"$LUA" -e "
package.preload.json = package.preload.json or function() return require 'dkjson' end
local noop = function() end
Runtime = { addEventListener=noop, removeEventListener=noop }
timer = { performWithDelay=noop, cancel=noop }
system = { pathForFile=function( f ) return f end, ResourceDirectory='.',
	getTimer=function() return os.clock()*1000 end }
local lunatest = require 'lunatest'
lunatest.suite( 'dmc_sockets_spec' )
lunatest.run()
" 2>&1 | grep -v '^Lua Patch::'
