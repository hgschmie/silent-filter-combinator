----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class ModThis
---@field other_mods string[]
---@field settings FrameworkSettings
---@field fico FilterCombinator
---@field runtime ModRuntime?
---@field gui ModGui?
local This = {
  other_mods = { 'nullius', 'framework', 'compaktcircuit', 'PickerDollies' },
  settings = Mod.settings:add_startup(require('scripts.settings-startup')),
  fico = require('scripts.filter-combinator'),
  runtime = nil,
  gui = nil,
}

if (script) then
  This.runtime = require('scripts.runtime') --[[@as ModRuntime ]]
  This.gui = require('scripts.gui') --[[@as ModGui ]]
end

----------------------------------------------------------------------------------------------------

return This
