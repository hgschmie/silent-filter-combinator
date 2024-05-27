local Events = require('__stdlib__.stdlib.event.event')

----------------------------------------------------------------------------------------------------

--- Runtime management
---@class ModRuntime
local Runtime = {
}

----------------------------------------------------------------------------------------------------



Events.on_load(function()
    -- self:rebuild_update_queue()
end)

return Runtime --[[ @as ModRuntime ]]
