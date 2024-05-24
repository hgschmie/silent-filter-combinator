local events = require('__stdlib__.stdlib.event.event')

local const = require('lib.constants')
local FiCo = require('scripts.filter_combinator')

--------------------------------------------------------------------------------
-- Module event setup
--------------------------------------------------------------------------------

---@class ModEvents
local ModEvents = {

}

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


function ModEvents:init()
    events.on_nth_tick(301, onNthTick)

    events.register({ defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined, defines.events.on_entity_died }, onEntityDeleted)
    events.register({ defines.events.on_built_entity, defines.events.on_robot_built_entity, defines.events.script_raised_revive }, onEntityCreated)
    events.register(defines.events.on_entity_cloned, onEntityCloned)
    events.register(defines.events.on_entity_settings_pasted, onEntitySettingsPasted)

    events.register(defines.events.on_player_setup_blueprint, onPlayerSetupBlueprint)
    events.register(defines.events.on_player_configured_blueprint, onPlayerConfiguredBlueprint)

    events.on_configuration_changed(onConfigurationChanged)

    -- events.register(defines.events.on_tick, run)
    -- events.register(defines.events.on_player_cursor_stack_changed, ensure_internal_connections)
    -- -- Config change
    -- events.register(defines.events.on_runtime_mod_setting_changed, cfg_update)
    -- -- Creation
    -- events.register(defines.events.on_entity_cloned, create, event_filter, "destination")
    -- events.register(defines.events.script_raised_built, create, event_filter)
    -- events.register(defines.events.script_raised_revive, create, event_filter)
    -- -- Rotation & settings pasting
    -- events.register(defines.events.on_player_rotated_entity, rotate, event_filter)
    -- -- Removal
    -- events.register(defines.events.on_robot_mined_entity, remove, event_filter)
    -- events.register(defines.events.script_raised_destroy, remove, event_filter)
    -- -- Batch removal
    -- events.register(defines.events.on_chunk_deleted, purge)
    -- events.register(defines.events.on_surface_cleared, purge)
    -- events.register(defines.events.on_surface_deleted, purge)
  end

return ModEvents