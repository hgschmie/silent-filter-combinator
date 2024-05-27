----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class ModThis
---@field settings FrameworkSettings?
---@field runtime ModRuntime?
---@field gui ModGui?
---@field other_mods string[]?
local This = {
  other_mods = nil,
  settings = nil,
  runtime = nil,
  gui = nil,
}

This.other_mods = { 'nullius', 'framework', 'compaktcircuit', 'PickerDollies' }
This.settings = Mod.settings:add_startup(require('scripts.settings-startup'))

-- self.StaCo = require("scripts/staco/staco")

if (script) then
  This.runtime = require('scripts.runtime') --[[@as ModRuntime ]]
  This.gui = require('scripts.gui') --[[@as ModGui ]]
end

----------------------------------------------------------------------------------------------------

return This
