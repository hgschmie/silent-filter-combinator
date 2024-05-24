----------------------------------------------------------------------------------------------------

--- Mod object access point
-- The main global singleton in the mod, defines globally used data and provides access to all
-- other components.
--- @class FrameworkMod
--- @field PREFIX string
--- @field NAME string
--- @field STORAGE string
--- @field settings FrameworkSettings?
--- @field logger FrameworkLogger?
--- @field runtime FrameworkRuntime?
local Mod = {
   --- The non-localised prefix (textual ID) of this mod.
   -- Must be set as the earliest possible time, as virtually all other framework parts use this.
   PREFIX = 'unknown-module-',

   --- Human readable, non-localized name
   NAME = '<unknown>',

   --- Name of the field in `global` to store framework persistent runtime data.
   STORAGE = "framework",

   settings = nil,

   logger = nil,

   runtime = nil,
}

---@param config table
function Mod:init(config)
   assert(config, 'no configuration provided')
   assert(config.name, 'config.name must contain the mod name')
   assert(config.prefix, 'config.prefix must contain the mod prefix')

   self.NAME = config.name
   self.PREFIX = config.prefix

   self.settings = require("framework.settings") --[[ @as FrameworkSettings ]]
   self.logger = require("framework.logger") --[[ @as FrameworkLogger ]]

   if config.log_tag then
      self.logger.MOD_TAG = config.log_tag
   end

   if (script) then
      self.runtime = require("framework.runtime")
      require("framework.event-setup"):register_all()
   end
end

---------------------------------------------------------------------------------------------------

return Mod
