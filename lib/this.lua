----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class ModThis
---@field settings FrameworkSettings?
---@field runtime ModRuntime?
---@field gui Gui
local This = {
  settings = nil,
  runtime = nil,
  gui = nil,
}

function This.init(self)
  self.settings = Mod.settings:add_startup(require("scripts.settings-startup"))

  -- self.StaCo = require("scripts/staco/staco")

  if (script) then
    self.runtime = require("scripts.runtime") --[[@as ModRuntime ]]
    self.runtime:init()

    self.gui = require("scripts.gui")
    self.gui.init()
  end
end

----------------------------------------------------------------------------------------------------

return This
