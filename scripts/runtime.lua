local events = require('__stdlib__.stdlib.event.event')

----------------------------------------------------------------------------------------------------

--- Runtime management
---@class ModRuntime
local Runtime = {
}

----------------------------------------------------------------------------------------------------


function Runtime:init()
   events.on_load(function()
         -- self:rebuild_update_queue()
    end)
end

return Runtime --[[ @as ModRuntime ]]
