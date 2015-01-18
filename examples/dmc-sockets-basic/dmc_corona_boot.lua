--====================================================================--
-- dmc_library_boot.lua
--
--  utility to read in dmc_library configuration file
--
-- by David McCuskey
-- Documentation:
--====================================================================--

--[[

Copyright (C) 2013-2014 David McCuskey. All Rights Reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in the
Software without restriction, including without limitation the rights to use, copy,
modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so, subject to the
following conditions:

The above copyright notice and this permission notice shall be included in all copies
or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

--]]



--====================================================================--
-- DMC Corona Library : DMC Corona Boot
--====================================================================--

-- Semantic Versioning Specification: http://semver.org/

local VERSION = "1.2.0"


--====================================================================--
-- Imports

local ok, json = pcall( require, 'json' )
if not ok then json = nil end


--====================================================================--
-- Setup Support
--====================================================================--

--== Start lua_files copies ==--

local File = {}

--====================================================================--
--== readFile() ==--

function File.readFile( file_path, options )
	-- print( "File.readFile", file_path )
	assert( type(file_path)=='string', "file path is not string" )
	assert( #file_path>0 )
	options = options or {}
	options.lines = options.lines == nil and true or options.lines
	--==--

	local fh, contents

	fh = assert( io.open(file_path, 'r') )

	if options.lines == false then
		-- read contents in one big string
		contents = fh:read( '*all' )

	else
		-- read all contents of file into a table
		contents = {}
		for line in fh:lines() do
			table.insert( contents, line )
		end

	end

	io.close( fh )

	return contents
end

function File.readFileLines( file_path, options )
	options = options or {}
	options.lines = true
	return File.readFile( file_path, options )
end

function File.readFileContents( file_path, options )
	options = options or {}
	options.lines = false
	return File.readFile( file_path, options )
end


--====================================================================--
--== read/write JSONFile() ==--

function File.convertLuaToJson( lua_data )
	assert( type(lua_data)=='table' )
	--==--
	return json.encode( lua_data )
end
function File.convertJsonToLua( json_str )
	assert( type(json_str)=='string' )
	assert( #json_str > 0 )
	--==--
	local data = json.decode( json_str )
	assert( data~=nil, "Error reading JSON file, probably malformed data" )
	return data
end


--====================================================================--
--== readConfigFile() ==--

function File.getLineType( line )
	-- print( "File.getLineType", #line, line )
	assert( type(line)=='string' )
	--==--
	local is_section, is_key = false, false
	if #line > 0 then
		is_section = ( string.find( line, '%[%w', 1, false ) == 1 )
		is_key = ( string.find( line, '%w', 1, false ) == 1 )
	end
	return is_section, is_key
end

function File.processSectionLine( line )
	-- print( "File.processSectionLine", line )
	assert( type(line)=='string' )
	assert( #line > 0 )
	--==--
	local key = line:match( "%[([%w_]+)%]" )
	return string.lower( key ) -- use only lowercase inside of module
end

function File.processKeyLine( line )
	-- print( "File.processKeyLine", line )
	assert( type(line)=='string' )
	assert( #line > 0 )
	--==--

	-- split up line
	local raw_key, raw_val = line:match( "([%w_:]+)%s*=%s*(.+)" )

	-- split up key parts
	local keys = {}
	for k in string.gmatch( raw_key, "([^:]+)") do
		table.insert( keys, #keys+1, k )
	end

	-- process key and value
	local key_name, key_type = unpack( keys )
	key_name = File.processKeyName( key_name )
	key_type = File.processKeyType( key_type )

	-- get final value
	if not key_type or type(key_type)~='string' then
		key_value = File.castTo_string( raw_val )

	else
		local method = 'castTo_'..key_type
		if File[ method ] then
			key_value = File[method]( raw_val )
		end
	end

	return key_name, key_value
end

function File.processKeyName( name )
	-- print( "File.processKeyName", name )
	assert( type(name)=='string' )
	assert( #name > 0 )
	--==--
	return string.lower( name ) -- use only lowercase inside of module
end
function File.processKeyType( name )
	-- print( "File.processKeyType", name )
	--==--
	if type(name)=='string' then
		name = string.lower( name ) -- use only lowercase inside of module
	end
	return name
end


function File.castTo_bool( value )
	assert( value=='true' or value == 'false' )
	--==--
	if value == 'true' then return true
	else return false end
end
function File.castTo_file( value )
	return File.castTo_string( value )
end
function File.castTo_int( value )
	assert( type(value)=='string' )
	--==--
	return tonumber( value )
end
function File.castTo_json( value )
	assert( type(value)=='string' )
	--==--
	return File.convertJsonToLua( value )
end
function File.castTo_path( value )
	assert( type(value)=='string' )
	--==--
	return string.gsub( value, '[/\\]', "." )
end
function File.castTo_string( value )
	assert( type(value)~='nil' or type(value)~='table' )
	return tostring( value )
end


function File.parseFileLines( lines, options )
	-- print( "parseFileLines", #lines )
	assert( options.default_section ~= nil )
	--==--

	local curr_section = options.default_section

	local config_data = {}
	config_data[ curr_section ]={}

	for _, line in ipairs( lines ) do
		local is_section, is_key = File.getLineType( line )
		-- print( line, is_section, is_key )

		if is_section then
			curr_section = File.processSectionLine( line )
			if not config_data[ curr_section ] then
				config_data[ curr_section ]={}
			end

		elseif is_key then
			local key, val = File.processKeyLine( line )
			config_data[ curr_section ][key] = val

		end
	end

	return config_data
end

-- @param file_path string full path to file
--
function File.readConfigFile( file_path, options )
	-- print( "File.readConfigFile", file_path )
	options = options or {}
	options.default_section = options.default_section or File.DEFAULT_CONFIG_SECTION
	--==--

	return File.parseFileLines( File.readFileLines( file_path ), options )
end

--== End lua_files copies ==--



--====================================================================--
-- Setup DMC Corona Library Config
--====================================================================--

-- This is standard code to bootstrap the dmc-corona-library
-- it looks for a configuration file to read

local DMC_CORONA_CONFIG_FILE = 'dmc_corona.cfg'
local DMC_CORONA_DEFAULT_SECTION = 'dmc_corona'

local dmc_lib_data, dmc_lib_info, dmc_lib_location

-- no module has yet tried to read in a config file
if _G.__dmc_corona == nil then
	local file_path, config_data
	file_path = system.pathForFile( DMC_CORONA_CONFIG_FILE, system.ResourceDirectory )
	if file_path ~= nil then
		config_data = File.readConfigFile( file_path, { default_section=DMC_CORONA_DEFAULT_SECTION } )
	end

	-- create/store config data
	_G.__dmc_corona = config_data or {}
	dmc_lib_data = _G.__dmc_corona
	-- create/setup library default
	dmc_lib_data.dmc_corona = dmc_lib_data.dmc_corona or {}
	dmc_lib_info = dmc_lib_data.dmc_corona

	-- enhance lua search path
	if dmc_lib_info.lua_path then
		local path_info = dmc_lib_info.lua_path
		local sys_path = system.pathForFile( system.ResourceDirectory )
		local lua_paths = { package.path }
		for i=#path_info, 1, -1 do
			local dir = path_info[i]
			local path = table.concat( { sys_path, dir, '?.lua;' }, '/' )
			table.insert( lua_paths, 1, path )
		end
		package.path = table.concat( lua_paths, '' )
		-- print( package.path )
	end

end

