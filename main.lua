--====================================================================--
-- Unit Tests for dmc_objects
--
-- Sample code is MIT licensed, the same license which covers Lua itself
-- http://en.wikipedia.org/wiki/MIT_License
-- Copyright (C) 2014-2015 David McCuskey. All Rights Reserved.
--====================================================================--



print( '\n\n##############################################\n\n' )



--====================================================================--
--== Imports

require 'tests.lunatest'



--====================================================================--
--== Setup test suites and run


lunatest.suite( 'tests.dmc_objects_spec' )
lunatest.run()
