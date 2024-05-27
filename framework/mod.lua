local Is = require('__stdlib__.stdlib.utils.is')

----------------------------------------------------------------------------------------------------

--- Mod object access point
-- The main global singleton in the mod, defines globally used data and provides access to all
-- other components.
--- @class FrameworkMod
--- @field PREFIX string
--- @field NAME string
--- @field STORAGE string
--- @field GAME_ID integer,
--- @field RUN_ID integer,
--- @field settings FrameworkSettings?
--- @field logger FrameworkLogger?
--- @field runtime FrameworkRuntime?
--- @field gui_manager FrameworkGuiManager?
Mod = {
    --- The non-localised prefix (textual ID) of this mod.
    -- Must be set as the earliest possible time, as virtually all other framework parts use this.
    PREFIX = 'unknown-module-',

    --- Human readable, non-localized name
    NAME = '<unknown>',

    --- Root location
    ROOT = '__unknown__',

    --- Name of the field in `global` to store framework persistent runtime data.
    STORAGE = 'framework',

    GAME_ID = -1,

    RUN_ID = -1,

    settings = nil,

    logger = nil,

    runtime = nil,

    gui_manager = nil,
}

--- Initialize the core framework.
--- the code itself references the global Mod
---@param config FrameworkModConfig table<string, any>|function config provider
function Mod:init(config)
    assert(Is.Function(config) or Is.Table(config), 'configuration must either be a table or a function that provides a table')
    if Is.Function(config) then
        config = config()
    end

    assert(config, 'no configuration provided')
    assert(config.name, 'config.name must contain the mod name')
    assert(config.prefix, 'config.prefix must contain the mod prefix')
    assert(config.root, 'config.root must be contain the module root name!')

    self.NAME = config.name
    self.PREFIX = config.prefix
    self.ROOT = config.root

    self.settings = require('framework.settings') --[[ @as FrameworkSettings ]]
    self.logger = require('framework.logger') --[[ @as FrameworkLogger ]]

    if (script) then
        -- runtime stage
        self.runtime = require('framework.runtime')

        self.logger:init()

        self.gui_manager = require('framework.gui_manager')

        require('framework.event-setup')
    elseif (settings) then
        -- prototype stage
        require('framework.prototype')
    end

    return self
end

---------------------------------------------------------------------------------------------------

return Mod

--- @class FrameworkModConfig
--- @field name string The human readable name for the module
--- @field prefix string A prefix for all game registered elements
--- @field root string The module root name
--- @field log_tag string? A custom logger tag
