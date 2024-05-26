----------------------------------------------------------------------------------------------------
--- Global definitions included in all phases
----------------------------------------------------------------------------------------------------

local const = require('lib.constants')

-- Framework core
Mod = require('framework.mod')

Mod:init(const.mod_init)

-- mod code
This = require("lib.this")
This:init()

----------------------------------------------------------------------------------------------------
