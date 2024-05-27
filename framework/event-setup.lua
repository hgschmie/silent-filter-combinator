----------------------------------------------------------------------------------------------------
--- Register all framework events
----------------------------------------------------------------------------------------------------

local Events = require('__stdlib__.stdlib.event.event')

----------------------------------------------------------------------------------------------------

-- Runtime settings changed
Events.register(defines.events.on_runtime_mod_setting_changed, function()
    Mod.settings:load('runtime', true)
    Mod.settings:load('player', true)
end)
