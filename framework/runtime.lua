local table = require('__stdlib__.stdlib.utils.table')

----------------------------------------------------------------------------------------------------

--- Main class governing the runtime.
-- Runtime exists during gameplay.
---@class FrameworkRuntime
local Runtime = {}

--- Framework storage, not intended for direct access from the mod
function Runtime:storage()
    if (not global[Mod.STORAGE]) then global[Mod.STORAGE] = {} end
    return global[Mod.STORAGE]
end

--- Write data to persistent storage.
-- @tparam table Data to save (simple values only).
function Runtime:save(fields)
    table.merge(global, fields)
    return self
end

--- Read data from persistent storage.
-- @treturn table Data stored in the persistent storage.
function Runtime:load()
    return table.deep_copy(global)
end

local function get_id(self, name, initial_function)
    if (self[name]) then return self[name] end
    assert(self:storage(), 'no framework storage found!')

    if self:storage()[name] then
        Mod.logger:debugf('Loaded %s from storage', name)
        self[name] = self:storage()[name]
    else
        self[name] = (initial_function and initial_function()) or 1
        Mod.logger:debugf('Created %s (%d)', name, self[name])
        self:storage()[name] = self[name]
    end
    return self[name]
end

--- Get game id, creating it if necessary.
--- Unique(-ish) ID for the current save, so that we can have one persistent log file per savegame.
--- Must be called from an event (e.g. on_load or on_init)
---@return integer game_id
function Runtime:get_game_id()
    return get_id(self, 'game_id', function() return math.random(100,999) end)
end

--- Get (generate if necessary) run ID. run id incremens for each call.
--- Unique(-ish) ID for the current save, so that we can have one persistent log file per savegame.
--- Must be called from an event (e.g. on_load or on_init)
---@return integer run_id
function Runtime:get_run_id()
    local run_id = get_id(self, 'run_id')
    self:storage().run_id = run_id + 1
    return run_id
end

----------------------------------------------------------------------------------------------------

return Runtime
