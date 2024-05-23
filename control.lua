-- Copyright 2023 Sil3ntStorm https://github.com/Sil3ntStorm
--
-- Licensed under MS-RL, see https://opensource.org/licenses/MS-RL

local const = require('lib.constants')

local FiCo = require('scripts.filter_combinator')

--- @param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive
local function onEntityCreated(event)
    local entity = event.created_entity or event.entity

    FiCo.create_entity(entity, event.tags)
end

local function onEntityDeleted(event)
    if (not (event.entity and event.entity.valid)) then
        return
    end
    FiCo.delete_entity(event.entity)
end

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

--- @param event EventData.on_entity_cloned
local function onEntityCloned(event)
    -- Space Exploration Support
    if (not (event.source and event.source.valid and event.destination and event.destination.valid)) then
        return
    end

    local src = event.source
    local dst = event.destination

    if string.sub(src.name, 1, const.name_prefix_len) ~= const.filter_combinator_name then return end

    FiCo.clone_entity(src, dst)
end


local function onEntitySettingsPasted(event)
    local pl = game.get_player(event.player_index)
    if not pl or not pl.valid or pl.force ~= event.source.force or pl.force ~= event.destination.force then
        return
    end
    if event.source.name ~= const.filter_combinator_name or event.destination.name ~= const.filter_combinator_name then
        return
    end
    local dest_idx = global.sil_filter_combinators[event.destination.unit_number]
    local source_idx = global.sil_filter_combinators[event.source.unit_number]
    if not dest_idx or not source_idx then
        return
    end
    local src = global.sil_fc_data[source_idx].cc
    local dst = global.sil_fc_data[dest_idx].cc
    if src and src.valid and src.force == pl.force and dst and dst.valid and dst.force == pl.force then
        dst.copy_settings(src)
    end
end

--#region Blueprint and copy / paste support

--- @param bp LuaItemStack
local function save_to_blueprint(data, bp)
    if not data then
        return
    end
    if #data < 1 then
        return
    end
    if not bp or not bp.is_blueprint_setup() then
        return
    end
    local entities = bp.get_blueprint_entities()
    if not entities or #entities < 1 then
        return
    end
    for _, unit in pairs(data) do
        local idx = global.sil_filter_combinators[unit]
        --- @type LuaEntity
        local src = global.sil_fc_data[idx].cc
        local main = global.sil_fc_data[idx].main

        local behavior = src.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
        for __, e in ipairs(entities) do
            -- Because LUA is a fucking useless piece of shit we cannot compare values that are tables... because you know why the fuck would you want to....
            -- if e.position == main.position then
            if e.position.x == main.position.x and e.position.y == main.position.y then
                bp.set_blueprint_entity_tag(__, 'config', global.sil_fc_data[idx].config)
                bp.set_blueprint_entity_tag(__, 'params', behavior.parameters)
                break
            end
        end
    end
end

--- @param event EventData.on_player_setup_blueprint
local function onPlayerSetupBlueprint(event)
    if not event.area then
        return
    end

    local player = game.players[event.player_index]
    local entities = player.surface.find_entities_filtered { area = event.area, force = player.force }
    local result = {}
    for _, ent in pairs(entities) do
        if ent.name == const.filter_combinator_name then
            table.insert(result, ent.unit_number)
        end
    end
    if #result < 1 then
        return
    end
    if player.cursor_stack.valid_for_read and player.cursor_stack.name == 'blueprint' then
        save_to_blueprint(result, player.cursor_stack)
    else
        -- Player is editing the blueprint, no access for us yet. Continue this in onPlayerConfiguredBlueprint
        if not global.sil_fc_blueprint_data then
            global.sil_fc_blueprint_data = {}
        end
        global.sil_fc_blueprint_data[event.player_index] = result
    end
end

--- @param event EventData.on_player_configured_blueprint
local function onPlayerConfiguredBlueprint(event)
    if not global.sil_fc_blueprint_data then
        global.sil_fc_blueprint_data = {}
    end
    local player = game.players[event.player_index]

    if player and player.cursor_stack and player.cursor_stack.valid_for_read and player.cursor_stack.name == 'blueprint' and global.sil_fc_blueprint_data[event.player_index] then
        save_to_blueprint(global.sil_fc_blueprint_data[event.player_index], player.cursor_stack)
    end
    if global.sil_fc_blueprint_data[event.player_index] then
        global.sil_fc_blueprint_data[event.player_index] = nil
    end
end

--#endregion

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

local function initCompat()
    if remote.interfaces["PickerDollies"] and remote.interfaces["PickerDollies"]["dolly_moved_entity_id"] then
        script.on_event(remote.call("PickerDollies", "dolly_moved_entity_id"), onEntityMoved)
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

--- @param changed ConfigurationChangedData
local function onConfigurationChanged(changed)
    global.sil_fc_slot_error_logged = false
    log('Updating for potentially changed signals...')
    for _, data in pairs(global.sil_fc_data) do
        if data and data.ex and data.ex.valid then
            FiCo.set_all_signals(data.ex)
        end
    end
end

local function onNthTick(event)
    if global.sil_fc_count <= 0 then return end
    for idx, data in pairs(global.sil_fc_data) do
        if not data.main.valid then
            -- most likely cc has removed the main entity
            local ids = data.ids
            for id, entity in pairs(ids) do
                assert(not global.sil_filter_combinators[id] or global.sil_filter_combinators[id] == idx)
                entity.destroy()
                global.sil_filter_combinators[id] = nil
            end
            FiCo.add_metatable(data.config):remove_data(idx)
        end
    end
end

script.on_nth_tick(301, onNthTick)

script.on_event({ defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined, defines.events.on_entity_died }, onEntityDeleted)
script.on_event({ defines.events.on_built_entity, defines.events.on_robot_built_entity, defines.events.script_raised_revive }, onEntityCreated)
script.on_event(defines.events.on_entity_cloned, onEntityCloned)
script.on_event(defines.events.on_entity_settings_pasted, onEntitySettingsPasted)

script.on_event(defines.events.on_player_setup_blueprint, onPlayerSetupBlueprint)
script.on_event(defines.events.on_player_configured_blueprint, onPlayerConfiguredBlueprint)

script.on_configuration_changed(onConfigurationChanged)

-- initialize the GUI
require('scripts.gui').init()

script.on_init(function()
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

script.on_load(function()
    initCompat()
end)
