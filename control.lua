-- Copyright 2023 Sil3ntStorm https://github.com/Sil3ntStorm
--
-- Licensed under MS-RL, see https://opensource.org/licenses/MS-RL

local Events = require('__stdlib__.stdlib.event.event')

require('lib.init')

local const = require('lib.constants')

local FiCo = require('scripts.filter_combinator')

--#region Compact Circuits Support

---@param entity LuaEntity
local function ccs_get_info(entity)
    local data = FiCo.locate_config(entity)
    if not data then return end

    local behavior = data.cc.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    return {
        cc_config = data.config,
        cc_params = behavior.parameters,
    }
end

---@param surface LuaSurface
---@param position MapPosition
---@param force LuaForce
local function ccs_create_packed_entity(info, surface, position, force)
    local ent = surface.create_entity { name = const.filter_combinator_name_packed, position = position, force = force, direction = info.direction, raise_built = false }

    if ent then
        local data = FiCo.create_entity(ent)
        data.config = FiCo.add_metatable(info.cc_config)

        local behavior = data.cc.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
        behavior.parameters = info.cc_params
        behavior.enabled = data.config.enabled
        data.ex.get_or_create_control_behavior().enabled = data.config.enabled
        data.config:update_entity(data)
    end
    return ent
end

---@param surface LuaSurface
---@param force LuaForce
local function ccs_create_entity(info, surface, force)
    local ent = surface.create_entity { name = const.filter_combinator_name, position = info.position, force = force, direction = info.direction, raise_built = false }
    if ent then
        local data = FiCo.create_entity(ent)
        data.config = FiCo.add_metatable(info.cc_config)

        local behavior = data.cc.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
        behavior.parameters = info.cc_params
        behavior.enabled = data.config.enabled
        data.ex.get_or_create_control_behavior().enabled = data.config.enabled
        data.config:update_entity(data)
    end
    return ent
end

--#endregion

local function onEntityMoved(event)
    -- Picker Dollies Support
    -- event.player_index
    -- event.mod_name
    -- event.name
    -- event.moved_entity
    -- event.start_pos
    -- event.tick
    if (not (event.moved_entity and event.moved_entity.valid)) then
        return
    end
    if event.moved_entity.name == const.filter_combinator_name then
       FiCo.move_entity(event.moved_entity)
    end
end


local function initCompat()
    if remote.interfaces["PickerDollies"] and remote.interfaces["PickerDollies"]["dolly_moved_entity_id"] then
        Events.on_event(remote.call("PickerDollies", "dolly_moved_entity_id"), onEntityMoved)
    end
    if remote.interfaces['PickerDollies'] and remote.interfaces['PickerDollies']['add_oblong_name'] then
        remote.call('PickerDollies', 'add_oblong_name', const.filter_combinator_name)
    end
    if script.active_mods['compaktcircuit'] and remote.interfaces['compaktcircuit'] and remote.interfaces['compaktcircuit']['add_combinator'] then
        remote.add_interface(const.filter_combinator_name, {
            get_info = ccs_get_info,
            create_packed_entity = ccs_create_packed_entity,
            create_entity = ccs_create_entity,
        })

        remote.call('compaktcircuit', 'add_combinator', {
            name = const.filter_combinator_name,
            packed_names = { const.filter_combinator_name_packed },
            interface_name = const.filter_combinator_name,
        })
    end
end

require('scripts.event-setup'):init()

require('scripts.gui').init()

Events.on_init(function()
    if not global.sil_filter_combinators then
        global.sil_filter_combinators = {}
    end
    if not global.sil_fc_data then
        --- @type FilterCombinatorData[]
        global.sil_fc_data = {}
    end
    global.sil_fc_count = 0
    initCompat()
end)

Events.on_load(function()
    initCompat()
end)
