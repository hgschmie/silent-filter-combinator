----------------------------------------------------------------------------------------------------
--- Global definitions included in all phases
----------------------------------------------------------------------------------------------------

local const = require('lib.constants')

-- Framework core
Mod = require('framework.mod')

Mod:init {
   -- prefix is the internal mod prefix
   prefix = const.prefix,
   -- name is a human readable name
   name = const.name,

   -- logging tag
   log_tag = '[img=item/' .. const.name .. ']'
}

-- mod code
This = require("lib.this")
This:init()

----------------------------------------------------------------------------------------------------
