--------------------------------------------------------------------------------
-- Module event setup
--------------------------------------------------------------------------------

local Event = require('__stdlib__/stdlib/event/event')
local Is = require('__stdlib__/stdlib/utils/is')

local const = require('lib.constants')

--------------------------------------------------------------------------------

--- @param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive
local function onEntityCreated(event)
    This.fico:create(event.created_entity, event.player_index)
end

local function onEntityDeleted(event)
    This.fico:destroy(event.entity.unit_number)
end

--- @param event EventData.on_entity_cloned
local function onMainEntityCloned(event)
    -- Space Exploration Support
    if not (Is.Valid(event.source) and Is.Valid(event.destination)) then return end

    local src_data = This.fico:entity(event.source.unit_number)
    if not src_data then return end

    local tags = { fc_config = src_data.config } -- clone the config from the src to the destination

    This.fico:create(event.destination, nil, tags)
end

local function onInternalEntityCloned(event)
    -- Space Exploration Support
    if not (Is.Valid(event.source) and Is.Valid(event.destination)) then return end

    -- delete the destination entity, it is not needed as the internal structure of the 
    -- filter combinator is recreated when the main entity is cloned
    event.destination.destroy()
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

--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------

--- @param changed ConfigurationChangedData?
local function onConfigurationChanged(changed)
    if This and This.fico then
        This.fico:clearAllSignalsConstantCombinator()

        for _,fc_entity in pairs(This.fico:entities()) do
            local all_signals = This.fico:getAllSignalsConstantCombinator(fc_entity)
            fc_entity.ref.ex.get_or_create_control_behavior().parameters = all_signals.get_or_create_control_behavior().parameters
        end
    end
end

local function onRuntimeModSettingChanged(ev)
    Mod.settings:flush()
    log(string.format("setting now: %s/%s",tostring(Mod.settings:player(ev.player_index).comb_visible), tostring(settings['player'][Mod.PREFIX .. "comb-visible"].value)))

    onConfigurationChanged()
end

--------------------------------------------------------------------------------

local function onNthTick(event)
    if This.fico:totalCount() <= 0 then return end
    for main_unit_number, fc_entity in pairs(This.fico:entities()) do
        if not Is.Valid(fc_entity.main) then
            -- most likely cc has removed the main entity
            This.fico:destroy(main_unit_number)
        else
            This.fico:update_entity(fc_entity)
        end
    end
end

--------------------------------------------------------------------------------

Event.on_nth_tick(301, onNthTick)

local main_names = { [const.filter_combinator_name] = true, [const.filter_combinator_name_packed] = true }

-- all internal entities
local internal_names = {
    [const.internal_ac_name] = true,
    [const.internal_cc_name] = true,
    [const.internal_dc_name] = true,
    [const.internal_debug_ac_name] = true,
    [const.internal_debug_cc_name] = true,
    [const.internal_debug_dc_name] = true,
}

local function match_main_entity(ev, pattern)
    local entity = ev and (ev.created_entity or ev.entity)
    return entity.name == const.filter_combinator_name
end

local function match_main_entities(ev, pattern)
    local entity = ev and (ev.created_entity or ev.entity)
    return main_names[entity.name]
end

local function match_internal_entities(ev, pattern)
    local entity = ev and (ev.created_entity or ev.entity)
    return internal_names[entity.name]
end

-- loop works around https://github.com/Afforess/Factorio-Stdlib/pull/164
for _, event in pairs { defines.events.on_built_entity, defines.events.on_robot_built_entity, defines.events.script_raised_revive } do
    Event.register(event, onEntityCreated, match_main_entities)
end

for _, event in pairs { defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined, defines.events.on_entity_died } do
    Event.register(event, onEntityDeleted)
end

Event.register(defines.events.on_entity_cloned, onMainEntityCloned, match_main_entities)
Event.register(defines.events.on_entity_cloned, onInternalEntityCloned, match_internal_entities)

Event.register(defines.events.on_entity_settings_pasted, onEntitySettingsPasted)

Event.register(defines.events.on_player_setup_blueprint, onPlayerSetupBlueprint)
Event.register(defines.events.on_player_configured_blueprint, onPlayerConfiguredBlueprint)

Event.on_configuration_changed(onConfigurationChanged)
Event.register(defines.events.on_runtime_mod_setting_changed, onRuntimeModSettingChanged)

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
