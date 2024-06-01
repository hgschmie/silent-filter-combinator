local table = require('__stdlib__/stdlib/utils/table')

----------------------------------------------------------------------------------------------------

--- Access to all mod settings
---@class FrameworkSettings
---@field definitions table<string, table>
local Settings = {
   --- Contains setting definitions
   -- Each field must be a table with `setting = <default value>` items, as well as containing a
   -- `NAMES` table mapping settings fields to their in-game names (fields not present in NAMES will
   -- be ignored).
   definitions = {
      startup = {
         debug_mode = { Mod.PREFIX .. 'debug-mode', false }
      },
      runtime = {},
      player = {},
   }
}

---@type table<string, table<string, (integer|boolean|double|string|Color)?>?>
local loaded = {
   --- Startup settings
   startup = nil,
   --- Runtime settings
   runtime = nil,
   --- Player settings
   player = nil,
}

---@class FrameworkSettings
---@field values table<string,(integer|boolean|double|string|Color)?>|table<string, table<string, (integer|boolean|double|string|Color)?>?>?
---@field load_value function(name: string, player_index: integer?): ModSetting?
---@field get_values function(self: FrameworkSettings, player_index: integer?): table<string, (integer|boolean|double|string|Color)?>
---@field set_values function(self: FrameworkSettings, values: table<string, (integer|boolean|double|string|Color)?>, player_index: integer?)
---@field clear function(self: FrameworkSettings, player_index: integer?)

---@type table<string, FrameworkSettings>
local settings_table = {
   startup = {
      values = nil,
      load_value = function(name) return settings.startup[name] end,
      get_values = function(self) return self.values end,
      set_values = function(self, values) self.values = values end,
      clear = function(self) self.values = nil end,
   },

   runtime = {
      values = nil,
      load_value = function(name) return settings.global[name] end,
      get_values = function(self) return self.values end,
      set_values = function(self, values) self.values = values end,
      clear = function(self) self.values = nil end,
   },

   player = {
      values = {},
      load_value = function(name, player_index)
         if player_index then
            local s = settings.get_player_settings(player_index)
            return s[name]
         else
            return settings['player'][name]
         end
      end,
      get_values = function(self, player_index)
         local index = player_index or 'default'
         return self.values[index]
      end,
      set_values = function(self, values, player_index)
         local index = player_index or 'default'
         self.values[index] = values
      end,
      clear = function(self, player_index)
         if player_index then
            self.values[player_index] = {}
         else
            self.values = {}
         end
      end,
   },
}

--- Add setting definitions of the given setting_type to the corresponding table
---@param setting_type string
---@param definitions table<string, any>
---@return self FrameworkSettings
function Settings:add_all(setting_type, definitions)
   table.merge(self.definitions[setting_type], definitions)

   settings_table[setting_type]:clear()
   return self
end

--- Add setting definitions to the startup table
---@param definitions table<string, any>
---@return self FrameworkSettings
function Settings:add_startup(definitions)
   return self:add_all('startup', definitions)
end

--- Add setting definitions to the runtime table
---@param definitions table<string, any>
---@return self FrameworkSettings
function Settings:add_runtime(definitions)
   return self:add_all('runtime', definitions)
end

--- Add setting definitions to the player table
---@param definitions table<string, any>
---@return self FrameworkSettings
function Settings:add_player(definitions)
   return self:add_all('player', definitions)
end

--- Access the mod's settings
---@param setting_type string Setting setting_type. Valid values are "startup", "runtime" and "player"
---@param reload boolean? Reload the settings from the game?
---@param player_index integer? The current player index.
---@return table<string, (integer|boolean|double|string|Color)?> result
function Settings:load(setting_type, reload, player_index)
   local st = settings_table[setting_type]

   if (not st:get_values(player_index) or reload) then
      local definition = self.definitions[setting_type]
      local values = {}
      st:set_values(values, player_index)

      for key, setting_def in pairs(definition) do
         if (type(setting_def) == 'table') then
            local value = st.load_value(setting_def[1], player_index).value
            if (value == nil) then
               value = setting_def[2]
            end
            values[key] = value
         end
      end
      Mod.logger:debugf("Loaded '%s' settings: %s", setting_type, serpent.line(st:get_values()))
   end
   return st:get_values(player_index) or error('Failed to load ' .. setting_type .. ' settings.')
end

function Settings:flush()
   settings_table['player']:clear()
   settings_table['runtime']:clear()
end

--- Access the mod's startup settings.
---@return table<string, (integer|boolean|double|string|Color)?> result
function Settings:startup()
   return self:load('startup')
end

--- Access the mods's runtime settings.
---@param reload boolean? Reload the settings from the game?
---@return table<string, (integer|boolean|double|string|Color)?> result
function Settings:runtime(reload)
   return self:load('runtime', reload)
end

--- Access the mods's player settings.
---@param player_index integer? The current player index.
---@param reload boolean? Reload the settings from the game?
---@return table<string, (integer|boolean|double|string|Color)?> result
function Settings:player(player_index, reload)
   return self:load('player', reload, player_index)
end

----------------------------------------------------------------------------------------------------

return Settings
