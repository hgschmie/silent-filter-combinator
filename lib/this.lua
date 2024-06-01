----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class ModThis
---@field other_mods string[]
---@field fico FilterCombinator
---@field runtime ModRuntime?
---@field gui ModGui?
local This = {
    other_mods = { 'nullius', 'framework', 'compaktcircuit', 'PickerDollies' },
    fico = require('scripts.filter-combinator'),
    runtime = nil,
    gui = nil,
}

Mod.settings:add_startup(require('scripts.settings-startup'))
Mod.settings:add_player(require('scripts.settings-player'))

if (script) then
    This.runtime = require('scripts.runtime') --[[@as ModRuntime ]]
    This.gui = require('scripts.gui') --[[@as ModGui ]]
end

----------------------------------------------------------------------------------------------------

return This
