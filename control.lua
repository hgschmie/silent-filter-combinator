-- Copyright 2023 Sil3ntStorm https://github.com/Sil3ntStorm
--
-- Licensed under MS-RL, see https://opensource.org/licenses/MS-RL

local const = require('lib.constants')

local flib_gui = require("__flib__/gui-lite")

local name_prefix_len = #const.filter_combinator_name

--- @param comb LuaEntity
local function set_all_signals(comb)
    local behavior = comb.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    local max = behavior.signals_count
    local idx = 1
    local had_error = false
    for sig_name, _ in pairs(game.item_prototypes) do
        if idx <= max then
            behavior.set_signal(idx, { signal = { type = 'item', name = sig_name }, count = 1 })
        elseif not had_error then
            had_error = true
        end
        idx = idx + 1
    end
    for sig_name, _ in pairs(game.fluid_prototypes) do
        if idx <= max then
            behavior.set_signal(idx, { signal = { type = 'fluid', name = sig_name }, count = 1 })
        elseif not had_error then
            had_error = true
        end
        idx = idx + 1
    end
    for sig_name, proto in pairs(game.virtual_signal_prototypes) do
        if not proto.special then
            if idx <= max then
                behavior.set_signal(idx, { signal = { type = 'virtual', name = sig_name }, count = 1 })
            elseif not had_error then
                had_error = true
            end
            idx = idx + 1
        end
    end
    if had_error and not global.sil_fc_slot_error_logged then
        log('!!! ERROR !!! Some mod(s) added ' ..
        max - idx + 1 ..
        ' additional items, fluids and / or signals AFTER the initial data stage, which is NOT supposed to be done by any mod! Exclusive mode might not work correctly. Please report this error and include a complete list of mods used.')
        global.sil_fc_slot_error_logged = true
    end
end

--- @return FilterCombinatorConfig
local function get_default_config()
    --- @type FilterCombinatorConfig
    local conf = {
        enabled = true,
        filter_input_from_wire = false,
        filter_input_wire = defines.wire_type.green,
        exclusive = false,
    }
    return conf
end

--- @param data FilterCombinatorData
local function update_entity(data)
    local non_filter_wire = defines.wire_type.red
    local filter_wire = defines.wire_type.green
    if data.config.filter_input_wire == defines.wire_type.red then
        non_filter_wire = defines.wire_type.green
        filter_wire = defines.wire_type.red
    end

    -- Disconnect main, which was potentially rewired for wire input based filtering
    data.main.disconnect_neighbour({ wire = defines.wire_type.red, target_entity = data.inp, target_circuit_id = defines.circuit_connector_id.combinator_input, source_circuit_id =
    defines.circuit_connector_id.combinator_input })
    data.main.disconnect_neighbour({ wire = defines.wire_type.green, target_entity = data.inp, target_circuit_id = defines.circuit_connector_id.combinator_input, source_circuit_id =
    defines.circuit_connector_id.combinator_input })
    data.main.disconnect_neighbour({ wire = defines.wire_type.red, target_entity = data.filter, target_circuit_id = defines.circuit_connector_id
    .combinator_input, source_circuit_id = defines.circuit_connector_id.combinator_input })
    data.main.disconnect_neighbour({ wire = defines.wire_type.green, target_entity = data.filter, target_circuit_id = defines.circuit_connector_id
    .combinator_input, source_circuit_id = defines.circuit_connector_id.combinator_input })
    if not data.config.enabled then
        -- If disabled nothing else to do after disconnecting main entity
        return
    end
    -- Disconnect configured input, which gets rewired for exclusive mode and wire input filtering
    data.cc.disconnect_neighbour(defines.wire_type.red)
    -- Disconnect inverter, which gets rewired for exclusive mode
    data.inv.disconnect_neighbour({ wire = defines.wire_type.red, target_entity = data.input_pos, target_circuit_id = defines.circuit_connector_id
    .combinator_input, source_circuit_id = defines.circuit_connector_id.combinator_output })
    data.inv.disconnect_neighbour({ wire = defines.wire_type.red, target_entity = data.input_neg, target_circuit_id = defines.circuit_connector_id
    .combinator_input, source_circuit_id = defines.circuit_connector_id.combinator_output })
    -- Disconnect filter, which gets rewired for wire input based filtering
    data.filter.disconnect_neighbour({ wire = defines.wire_type.red, target_entity = data.input_pos, target_circuit_id = defines.circuit_connector_id
    .combinator_input, source_circuit_id = defines.circuit_connector_id.combinator_output })
    data.filter.disconnect_neighbour({ wire = defines.wire_type.red, target_entity = data.input_neg, target_circuit_id = defines.circuit_connector_id
    .combinator_input, source_circuit_id = defines.circuit_connector_id.combinator_output })
    if data.config.exclusive and not data.config.filter_input_from_wire then
        -- All but the configured signals
        data.inv.connect_neighbour({ wire = defines.wire_type.red, target_entity = data.input_pos, target_circuit_id = defines.circuit_connector_id
        .combinator_input, source_circuit_id = defines.circuit_connector_id.combinator_output })
        data.inv.connect_neighbour({ wire = defines.wire_type.red, target_entity = data.input_neg, target_circuit_id = defines.circuit_connector_id
        .combinator_input, source_circuit_id = defines.circuit_connector_id.combinator_output })
        data.main.connect_neighbour({ wire = defines.wire_type.red, target_entity = data.inp, target_circuit_id = defines.circuit_connector_id.combinator_input, source_circuit_id =
        defines.circuit_connector_id.combinator_input })
        data.main.connect_neighbour({ wire = defines.wire_type.green, target_entity = data.inp, target_circuit_id = defines.circuit_connector_id
        .combinator_input, source_circuit_id = defines.circuit_connector_id.combinator_input })
        data.cc.connect_neighbour({ wire = defines.wire_type.red, target_entity = data.inv, target_circuit_id = defines.circuit_connector_id.combinator_input })
    elseif not data.config.filter_input_from_wire then
        -- Default config
        data.cc.connect_neighbour({ wire = defines.wire_type.red, target_entity = data.input_pos, target_circuit_id = defines.circuit_connector_id
        .combinator_input })
        data.cc.connect_neighbour({ wire = defines.wire_type.red, target_entity = data.input_neg, target_circuit_id = defines.circuit_connector_id
        .combinator_input })
        data.main.connect_neighbour({ wire = defines.wire_type.red, target_entity = data.inp, target_circuit_id = defines.circuit_connector_id.combinator_input, source_circuit_id =
        defines.circuit_connector_id.combinator_input })
        data.main.connect_neighbour({ wire = defines.wire_type.green, target_entity = data.inp, target_circuit_id = defines.circuit_connector_id
        .combinator_input, source_circuit_id = defines.circuit_connector_id.combinator_input })
    elseif data.config.exclusive then
        -- All but those present on an input wire
        data.main.connect_neighbour({ wire = non_filter_wire, target_entity = data.inp, target_circuit_id = defines.circuit_connector_id.combinator_input, source_circuit_id =
        defines.circuit_connector_id.combinator_input })
        data.main.connect_neighbour({ wire = filter_wire, target_entity = data.filter, target_circuit_id = defines.circuit_connector_id.combinator_input, source_circuit_id =
        defines.circuit_connector_id.combinator_input })
        data.inv.connect_neighbour({ wire = defines.wire_type.red, target_entity = data.input_pos, target_circuit_id = defines.circuit_connector_id
        .combinator_input, source_circuit_id = defines.circuit_connector_id.combinator_output })
        data.inv.connect_neighbour({ wire = defines.wire_type.red, target_entity = data.input_neg, target_circuit_id = defines.circuit_connector_id
        .combinator_input, source_circuit_id = defines.circuit_connector_id.combinator_output })
    else
        -- Wire input is the signals we want
        data.main.connect_neighbour({ wire = non_filter_wire, target_entity = data.inp, target_circuit_id = defines.circuit_connector_id.combinator_input, source_circuit_id =
        defines.circuit_connector_id.combinator_input })
        data.main.connect_neighbour({ wire = filter_wire, target_entity = data.filter, target_circuit_id = defines.circuit_connector_id.combinator_input, source_circuit_id =
        defines.circuit_connector_id.combinator_input })
        data.filter.connect_neighbour({ wire = defines.wire_type.red, target_entity = data.input_pos, target_circuit_id = defines.circuit_connector_id
        .combinator_input, source_circuit_id = defines.circuit_connector_id.combinator_output })
        data.filter.connect_neighbour({ wire = defines.wire_type.red, target_entity = data.input_neg, target_circuit_id = defines.circuit_connector_id
        .combinator_input, source_circuit_id = defines.circuit_connector_id.combinator_output })
    end
end

--- @param main LuaEntity
--- @param tags Tags?
local function create_entity(main, tags)
    if not (main and main.valid and (main.name == const.filter_combinator_name or main.name == const.filter_combinator_name_packed)) then return end

    local signal_each = { type = 'virtual', name = 'signal-each' }

    global.sil_filter_combinators[main.unit_number] = main.unit_number

    local ids = {}
    ids[main.unit_number] = main

    local create_internal_entity = function(main, proto)
        local ent = main.surface.create_entity {
            name = proto,
            position = main.position,
            force = main.force,
            create_build_effect_smoke = false,
            spawn_decorations = false,
            move_stuck_players = true,
        }
        global.sil_filter_combinators[ent.unit_number] = main.unit_number
        ids[ent.unit_number] = ent

        return ent
    end

    --- @type FilterCombinatorConfig
    local conf = get_default_config()

    -- Logic Circuitry Entities
    local cc = create_internal_entity(main, const.internal_cc_name)
    local d1 = create_internal_entity(main, const.internal_dc_name)
    local d2 = create_internal_entity(main, const.internal_dc_name)
    local d3 = create_internal_entity(main, const.internal_dc_name)
    local d4 = create_internal_entity(main, const.internal_dc_name)
    local a1 = create_internal_entity(main, const.internal_ac_name)
    local a2 = create_internal_entity(main, const.internal_ac_name)
    local a3 = create_internal_entity(main, const.internal_ac_name)
    local a4 = create_internal_entity(main, const.internal_ac_name)
    local ccf = create_internal_entity(main, const.internal_dc_name)
    local out = create_internal_entity(main, const.internal_ac_name)
    local ex = create_internal_entity(main, const.internal_cc_name)
    local inv = create_internal_entity(main, const.internal_ac_name)

    local data = {
        ids = ids,
        config = conf,
        main = main,
        cc = cc,
        calc = { d1, d2, d3, d4, a1, a2, a3, a4, ccf, out, inv },
        ex = ex,
        inv = inv,
        input_pos = a3,
        input_neg = a1,
        filter = ccf,
        inp = d1,
    }

    -- Check if this was a blueprint which we added custom data to
    if tags then
        local behavior = cc.get_or_create_control_behavior()
        if tags.config ~= nil and tags.params ~= nil then
            conf = tags.config --[[@as FilterCombinatorConfig]]
            behavior.parameters = tags.params
        elseif tags.cc_config ~= nil and tags.cc_params ~= nil then
            -- compakt combinator code uses cc_ for some reason...
            conf = tags.cc_config --[[@as FilterCombinatorConfig]]
            behavior.parameters = tags.cc_params
        end
        behavior.enabled = conf.enabled
        ex.get_or_create_control_behavior().enabled = conf.enabled
    end

    -- Set up Exclusive mode Combinator signals
    set_all_signals(ex)
    -- Set Conditions
    ccf.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, comparator = '!=', copy_count_from_input = false }
    out.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, operation = '+', second_constant = 0 }
    d1.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, comparator = '<' }
    d2.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, comparator = '>' }
    a1.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, operation = '*', second_constant = 0 -
    (2 ^ 31 - 1) }
    a2.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, operation = '*', second_constant = -1 }
    d3.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, comparator = '>' }
    a3.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, operation = '*', second_constant = 2 ^ 31 - 1 }
    a4.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, operation = '*', second_constant = -1 }
    d4.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, comparator = '<' }
    inv.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, operation = '*', second_constant = -1 }

    -- Exclusive Mode
    ex.connect_neighbour({ wire = defines.wire_type.red, target_entity = inv, target_circuit_id = defines.circuit_connector_id.combinator_output })
    cc.connect_neighbour({ wire = defines.wire_type.red, target_entity = inv, target_circuit_id = defines.circuit_connector_id.combinator_input })
    -- Connect Logic
    ccf.connect_neighbour({ wire = defines.wire_type.red, target_entity = inv, target_circuit_id = defines.circuit_connector_id.combinator_input, source_circuit_id =
    defines.circuit_connector_id.combinator_output })
    d1.connect_neighbour({ wire = defines.wire_type.red, target_entity = d2, target_circuit_id = defines.circuit_connector_id.combinator_input, source_circuit_id =
    defines.circuit_connector_id.combinator_input })
    d1.connect_neighbour({ wire = defines.wire_type.green, target_entity = d2, target_circuit_id = defines.circuit_connector_id.combinator_input, source_circuit_id =
    defines.circuit_connector_id.combinator_input })
    -- Negative Inputs
    a1.connect_neighbour({ wire = defines.wire_type.red, target_entity = cc, source_circuit_id = defines.circuit_connector_id.combinator_input })
    a2.connect_neighbour({ wire = defines.wire_type.red, target_entity = a1, target_circuit_id = defines.circuit_connector_id.combinator_output, source_circuit_id =
    defines.circuit_connector_id.combinator_input })
    d3.connect_neighbour({ wire = defines.wire_type.red, target_entity = a2, target_circuit_id = defines.circuit_connector_id.combinator_output, source_circuit_id =
    defines.circuit_connector_id.combinator_input })
    d3.connect_neighbour({ wire = defines.wire_type.red, target_entity = d1, target_circuit_id = defines.circuit_connector_id.combinator_output, source_circuit_id =
    defines.circuit_connector_id.combinator_input })
    -- Positive Inputs
    a3.connect_neighbour({ wire = defines.wire_type.red, target_entity = cc, source_circuit_id = defines.circuit_connector_id.combinator_input })
    a4.connect_neighbour({ wire = defines.wire_type.red, target_entity = a3, target_circuit_id = defines.circuit_connector_id.combinator_output, source_circuit_id =
    defines.circuit_connector_id.combinator_input })
    d4.connect_neighbour({ wire = defines.wire_type.red, target_entity = a4, target_circuit_id = defines.circuit_connector_id.combinator_output, source_circuit_id =
    defines.circuit_connector_id.combinator_input })
    d4.connect_neighbour({ wire = defines.wire_type.red, target_entity = d2, target_circuit_id = defines.circuit_connector_id.combinator_output, source_circuit_id =
    defines.circuit_connector_id.combinator_input })
    -- Wire up output (to be able to use any color wire again)
    out.connect_neighbour({ wire = defines.wire_type.green, target_entity = a1, target_circuit_id = defines.circuit_connector_id.combinator_output, source_circuit_id =
    defines.circuit_connector_id.combinator_input })
    out.connect_neighbour({ wire = defines.wire_type.green, target_entity = d3, target_circuit_id = defines.circuit_connector_id.combinator_output, source_circuit_id =
    defines.circuit_connector_id.combinator_input })
    out.connect_neighbour({ wire = defines.wire_type.green, target_entity = a3, target_circuit_id = defines.circuit_connector_id.combinator_output, source_circuit_id =
    defines.circuit_connector_id.combinator_input })
    out.connect_neighbour({ wire = defines.wire_type.green, target_entity = d4, target_circuit_id = defines.circuit_connector_id.combinator_output, source_circuit_id =
    defines.circuit_connector_id.combinator_input })
    -- Connect main entity
    main.connect_neighbour({ wire = defines.wire_type.red, target_entity = out, target_circuit_id = defines.circuit_connector_id.combinator_output, source_circuit_id =
    defines.circuit_connector_id.combinator_output })
    main.connect_neighbour({ wire = defines.wire_type.green, target_entity = out, target_circuit_id = defines.circuit_connector_id.combinator_output, source_circuit_id =
    defines.circuit_connector_id.combinator_output })
    main.connect_neighbour({ wire = defines.wire_type.red, target_entity = d1, target_circuit_id = defines.circuit_connector_id.combinator_input, source_circuit_id =
    defines.circuit_connector_id.combinator_input })
    main.connect_neighbour({ wire = defines.wire_type.green, target_entity = d1, target_circuit_id = defines.circuit_connector_id.combinator_input, source_circuit_id =
    defines.circuit_connector_id.combinator_input })
    -- Store Entities
    assert(not global.sil_fc_data[main.unit_number])
    global.sil_fc_data[main.unit_number] = data
    global.sil_fc_count = global.sil_fc_count + 1

    -- check for default config
    if not (conf.enabled == true and conf.filter_input_from_wire == false and conf.filter_input_wire == defines.wire_type.green and conf.exclusive == false) then
        update_entity(global.sil_fc_data[main.unit_number])
    end
end


---Returns the filter combinator configuration or nil
---@param entity LuaEntity
---@return FilterCombinatorData? config The filter combinator configuration
---@return integer match The index in the data array
local function locate_config(entity)
    if not (entity and entity.valid) then return nil, -1 end
    local match = global.sil_filter_combinators[entity.unit_number]
    if not match then return nil, -1 end
    return global.sil_fc_data[match], match
end

local function remove_data(unit_number)
    -- null out the configuration
    if global.sil_fc_data[unit_number] then
        global.sil_fc_data[unit_number] = nil
        global.sil_fc_count = global.sil_fc_count - 1

        if global.sil_fc_count < 0 then
            global.sil_fc_count = table_size(global.sil_fc_data)
            log("Filter Combinator count got negative (bug), size is now: " .. global.sil_fc_count)
        end
    end
end

--- @param entity LuaEntity
local function delete_entity(entity)
    if string.sub(entity.name, 1, name_prefix_len) ~= const.filter_combinator_name then return end

    local data, match = locate_config(entity)
    if not data then return end

    assert(data.main.valid and entity.valid and data.main.unit_number == entity.unit_number)

    for idx, entity in pairs(data.ids) do
        entity.destroy()
        global.sil_filter_combinators[idx] = nil
    end

    remove_data(match)
end

--- @param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive
local function onEntityCreated(event)
    local entity = event.created_entity or event.entity

    create_entity(entity, event.tags)
end

local function onEntityDeleted(event)
    if (not (event.entity and event.entity.valid)) then
        return
    end
    delete_entity(event.entity)
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
        local data = locate_config(event.moved_entity)
        if data then
            if data.cc and data.cc.valid then
                data.cc.teleport(event.moved_entity.position)
            end
            if data.ex and data.ex.valid then
                data.ex.teleport(event.moved_entity.position)
            end
            if data.calc then
                for _, e in pairs(data.calc) do
                    if e and e.valid then
                        e.teleport(event.moved_entity.position)
                    end
                end
            end
        end
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

    if string.sub(src.name, 1, name_prefix_len) ~= const.filter_combinator_name then return end

    local data = locate_config(src)
    if not data then return end

    local function replace_combinator(old, new)
        data.ids[old.unit_number] = nil
        data.ids[new.unit_number] = new
    end

    local src_unit = src.unit_number
    if src.name == const.filter_combinator_name then
        replace_combinator(data.main, dst)
        data.main = dst
    elseif src.name == const.internal_ac_name or src.name == const.internal_dc_name then
        for i, e in pairs(data.calc) do
            if e and e.valid and e.unit_number == src_unit then
                replace_combinator(data.calc[i], dst)
                data.calc[i] = dst
                break
            end
        end
        if src_unit == data.inv.unit_number then
            replace_combinator(data.inv, dst)
            data.inv = dst
        elseif src_unit == data.input_pos.unit_number then
            replace_combinator(data.input_pos, dst)
            data.input_pos = dst
        elseif src_unit == data.input_neg.unit_number then
            replace_combinator(data.input_neg, dst)
            data.input_neg = dst
        elseif src_unit == data.filter.unit_number then
            replace_combinator(data.filter, dst)
            data.filter = dst
        elseif src_unit == data.inp.unit_number then
            replace_combinator(data.inp, dst)
            data.inp = dst
        end
    elseif src.name == const.internal_cc_name then
        if data.cc.unit_number == src_unit then
            replace_combinator(data.cc, dst)
            data.cc = dst
        elseif data.ex.unit_number == src_unit then
            replace_combinator(data.ex, dst)
            data.ex = dst
        else
            log('Failed to update ' .. src.name .. ' ' .. src_unit .. ' -> ' .. dst.unit_number)
        end
    else
        log('Unmatched entity ' .. src.name)
    end
    global.sil_filter_combinators[dst.unit_number] = global.sil_filter_combinators[src_unit]
    global.sil_filter_combinators[src_unit] = nil
end

--#region gui

--- @param player LuaPlayer
local function destroy_gui(player)
    if not global.sil_fc_gui then
        global.sil_fc_gui = {}
    end
    local ui = global.sil_fc_gui[player.index]
    if not ui then
        return
    end
    local main = ui.ui.sil_fc_filter_ui
    if not (main and main.valid) then
        return
    end
    if player.opened == main then
        player.opened = nil
    end
    main.destroy()
end

--- @param event EventData.on_gui_click
local function on_window_closed(event)
    destroy_gui(game.players[event.player_index])
end

--- @param event EventData.on_gui_switch_state_changed
local function on_switch_enabled(event)
    local ui = global.sil_fc_gui[event.player_index]
    if not ui then
        return
    end

    local match = global.sil_filter_combinators[ui.unit]
    if not match then
        return
    end
    local data = global.sil_fc_data[match]
    if not (data and data.config) then
        return
    end
    data.config.enabled = event.element.switch_state == "right"
    data.cc.get_or_create_control_behavior().enabled = data.config.enabled
    data.ex.get_or_create_control_behavior().enabled = data.config.enabled
    data.main.active = data.config.enabled
    ui.ui.sil_fc_content.status_flow.status.caption = data.config.enabled and { 'entity-status.working' } or { 'entity-status.disabled' }
    ui.ui.sil_fc_content.status_flow.lamp.sprite = data.config.enabled and 'flib_indicator_green' or 'flib_indicator_red'
    update_entity(data)
end

--- @param event EventData.on_gui_switch_state_changed
local function on_switch_exclusive(event)
    local ui = global.sil_fc_gui[event.player_index]
    if not ui then
        return
    end
    local match = global.sil_filter_combinators[ui.unit]
    if not match then
        return
    end
    local data = global.sil_fc_data[match]
    if not (data and data.config) then
        return
    end
    data.config.exclusive = event.element.switch_state == "right"
    update_entity(data)
end

--- @param event EventData.on_gui_checked_state_changed
local function on_switch_wire(event)
    local ui = global.sil_fc_gui[event.player_index]
    if not ui then
        return
    end
    local match = global.sil_filter_combinators[ui.unit]
    if not match then
        return
    end
    local data = global.sil_fc_data[match]
    if not (data and data.config) then
        return
    end
    if event.element.name == "sil_fc_red_wire" then
        data.config.filter_input_wire = defines.wire_type.red
        ui.ui.sil_fc_content.sil_fc_row2.sil_fc_green_wire.state = not event.element.state
    elseif event.element.name == "sil_fc_green_wire" then
        data.config.filter_input_wire = defines.wire_type.green
        ui.ui.sil_fc_content.sil_fc_row2.sil_fc_red_wire.state = not event.element.state
    else
        return
    end
    update_entity(data)
end

--- @param event  EventData.on_gui_checked_state_changed
local function on_toggle_wire_mode(event)
    local ui = global.sil_fc_gui[event.player_index]
    if not ui then
        return
    end
    local match = global.sil_filter_combinators[ui.unit]
    if not match then
        return
    end
    local data = global.sil_fc_data[match]
    if not (data and data.config) then
        return
    end
    -- ui.ui.sil_fc_content.sil_fc_row2.sil_fc_red_wire.enabled = event.element.state
    -- ui.ui.sil_fc_content.sil_fc_row2.sil_fc_green_wire.enabled = event.element.state
    data.config.filter_input_from_wire = event.element.state
    ui.ui.sil_fc_content.sil_fc_row3.visible = not event.element.state
    update_entity(data)
end

--- @param event EventData.on_gui_elem_changed
local function on_signal_selected(event)
    local ui = global.sil_fc_gui[event.player_index]
    if not ui then
        return
    end
    if not event.element.tags then
        return
    end
    local match = global.sil_filter_combinators[ui.unit]
    if not match then
        return
    end
    local data = global.sil_fc_data[match]
    if not (data and data.config) then
        return
    end
    local signal = event.element.elem_value;
    local slot = event.element.tags.idx --[[@as integer]]
    local behavior = data.cc.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    behavior.set_signal(slot, signal and { signal = signal, count = 1 } or nil)
end

-- for some reason this shit ain't doing anything
flib_gui.add_handlers({
    on_window_closed = on_window_closed,
    on_switch_enabled = on_switch_enabled,
    on_switch_exclusive = on_switch_exclusive,
    on_switch_wire = on_switch_wire,
    on_toggle_wire = on_toggle_wire_mode,
    on_select_signal = on_signal_selected,
})
local handler = require("__core__.lualib.event_handler")
handler.add_lib(flib_gui)
flib_gui.handle_events()

--- @param cc LuaEntity
local function make_grid_buttons(cc)
    local behavior = cc.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    local list = {}
    local empty_slot_count = 0
    -- For some reason it always is a table as big as the max signals supported... kinda unexpected but it works out I guess
    for i = 1, behavior.signals_count do
        local sig = behavior.get_signal(i)
        if (sig.signal) then
            table.insert(list,
                { type = 'choose-elem-button', tags = { idx = i }, style = 'slot_button', elem_type = 'signal', signal = sig.signal, handler = { [defines.events.on_gui_elem_changed] = on_signal_selected } })
        elseif empty_slot_count < settings.startup['sfc-empty-slots'].value or #list % 10 ~= 0 then
            empty_slot_count = empty_slot_count + 1
            table.insert(list,
                { type = 'choose-elem-button', tags = { idx = i }, style = 'slot_button', elem_type = 'signal', handler = { [defines.events.on_gui_elem_changed] = on_signal_selected } })
        end
    end
    return list
end


--- @param event EventData.on_gui_opened
local function onGuiOpen(event)
    if not (event.entity and event.entity.valid and event.entity.name == const.filter_combinator_name) then
        -- some other GUI was opened, we don't care
        return
    end

    local data = locate_config(event.entity)
    local player = game.players[event.player_index]
    if not data then
        log('Data missing for ' ..
        event.entity.name .. ' on ' .. event.entity.surface.name .. ' at ' .. serpent.line(event.entity.position) .. ' refusing to display UI')
        player.opened = nil
        return
    end

    destroy_gui(player)

    if not (data.cc and data.cc.valid) then
        player.opened = nil
        return
    end

    local slot_buttons = make_grid_buttons(data.cc)
    --- @type GuiElemDef
    local ui = {
        type = "frame",
        name = "sil_fc_filter_ui",
        direction = "vertical",
        handler = { [defines.events.on_gui_closed] = on_window_closed },
        { -- Title Bar
            type = "flow",
            style = "flib_titlebar_flow",
            drag_target = "sil_fc_filter_ui",
            {
                type = "label",
                style = "frame_title",
                caption = { const.fc_entity_name },
                drag_target = "sil_fc_filter_ui",
                ignored_by_interaction = true,
            },
            {
                type = "empty-widget",
                style = "flib_titlebar_drag_handle",
                ignored_by_interaction = true,
            },
            {
                type = "sprite-button",
                name = "sil_fc_close_button",
                style = "frame_action_button",
                sprite = "utility/close_white",
                hovered_sprite = "utility/close_black",
                clicked_sprite = "utility/close_black",
                mouse_button_filter = { "left" },
                handler = { [defines.events.on_gui_click] = on_window_closed },
            },
        }, -- Title Bar End
        {
            type = "frame",
            style = "inside_shallow_frame_with_padding",
            name = "sil_fc_content",
            direction = "vertical",
            {
                type = "flow",
                style = "flib_indicator_flow",
                name = "status_flow",
                {
                    type = "sprite",
                    name = "lamp",
                    style = "flib_indicator",
                    sprite = data.config.enabled and "flib_indicator_green" or "flib_indicator_red",
                },
                {
                    type = "label",
                    style = "label",
                    name = "status",
                    caption = data.config.enabled and { 'entity-status.working' } or { 'entity-status.disabled' },
                },
                {
                    type = "empty-widget",
                    spacer = { style = { horizontally_stretchable = true } },
                },
                {                
                    type = "label",
                    style = 'label',
                    name = 'id',
                    caption = "ID: " .. data.main.unit_number
                },
            },
            { -- Add some spacing
                type = "frame",
                style = "container_invisible_frame_with_title",
            },
            {
                type = "frame",
                style = "deep_frame_in_shallow_frame",
                name = "preview_frame",
                {
                    type = "entity-preview",
                    name = "preview",
                    style = "wide_entity_button",
                },
            },
            { -- Add some spacing
                type = "frame",
                style = "container_invisible_frame_with_title",
            },
            {
                type = "frame",
                style = "container_invisible_frame_with_title",
                {
                    type = "label",
                    style = "heading_3_label",
                    caption = { 'gui-constant.output' },
                },
            },
            {
                type = "switch",
                switch_state = data.config.enabled and "right" or "left",
                right_label_caption = { 'gui-constant.on' },
                left_label_caption = { 'gui-constant.off' },
                handler = { [defines.events.on_gui_switch_state_changed] = on_switch_enabled },
            },
            { -- Add some spacing
                type = "frame",
                style = "container_invisible_frame_with_title",
            },
            {
                type = "frame",
                style = "container_invisible_frame_with_title",
                {
                    type = "label",
                    style = "heading_3_label",
                    caption = { const:locale('mode-heading') },
                },
            },
            {
                type = "switch",
                switch_state = data.config.exclusive and "right" or "left",
                right_label_caption = { const:locale('mode-exclusive') },
                right_label_tooltip = { const:locale('mode-exclusive-tooltip') },
                left_label_caption = { const:locale('mode-inclusive') },
                left_label_tooltip = { const:locale('mode-inclusive-tooltip') },
                handler = { [defines.events.on_gui_switch_state_changed] = on_switch_exclusive },
            },
            { -- Add some spacing
                type = "frame",
                style = "container_invisible_frame_with_title",
            },
            {
                type = "flow",
                name = "sil_fc_row2",
                direction = "horizontal",
                {
                    type = "checkbox",
                    caption = { const:locale('mode-wire') },
                    name = "sil_fc_wire_content",
                    state = data.config.filter_input_from_wire,
                    handler = { [defines.events.on_gui_checked_state_changed] = on_toggle_wire_mode },
                },
                {
                    type = "radiobutton",
                    state = data.config.filter_input_wire == defines.wire_type.red,
                    -- enabled = data.config.filter_input_from_wire,
                    caption = { 'item-name.red-wire' },
                    name = "sil_fc_red_wire",
                    handler = { [defines.events.on_gui_checked_state_changed] = on_switch_wire },
                },
                {
                    type = "radiobutton",
                    state = data.config.filter_input_wire == defines.wire_type.green,
                    -- enabled = data.config.filter_input_from_wire,
                    caption = { 'item-name.green-wire' },
                    name = "sil_fc_green_wire",
                    handler = { [defines.events.on_gui_checked_state_changed] = on_switch_wire },
                },
            },
            { -- Just so we can hide this entire block in one go
                type = "flow",
                direction = "vertical",
                visible = not data.config.filter_input_from_wire,
                name = "sil_fc_row3",
                { -- Add some spacing
                    type = "frame",
                    style = "container_invisible_frame_with_title",
                },
                {
                    type = "line",
                },
                {
                    type = "frame",
                    style = "container_invisible_frame_with_title",
                    {
                        type = "label",
                        style = "heading_3_label",
                        caption = { const:locale('signals-heading') },
                    },
                },
                {
                    type = "scroll-pane",
                    style = "constant_combinator_logistics_scroll_pane",
                    name = "sil_fc_filter_section",
                    {
                        type = "frame",
                        style = "deep_frame_in_shallow_frame",
                        name = "frame",
                        {
                            type = "table",
                            name = "sil_fc_signal_container",
                            style = 'sil_signal_table',
                            -- style = "compact_slot_table", -- Best vanilla match, still too wide a gap
                            -- style = "slot_table", -- No real difference to the compact one?
                            -- style = "filter_slot_table", -- Correct but has light background instead of dark
                            -- style = "logistics_slot_table", -- Same as above
                            -- style = "filter_group_table", -- Kinda weird with dark in between some but not all?
                            -- style = "inset_frame_container_table", -- Massive gaps
                            -- style = "logistic_gui_table", -- even worse gaps. No idea where this is ever used
                            column_count = 10,
                            children = slot_buttons,
                        },
                    },
                },
            },
        },
    }
    if not global.sil_fc_gui then
        global.sil_fc_gui = {}
    end
    local created = flib_gui.add(player.gui.screen, ui)
    created.sil_fc_filter_ui.auto_center = true
    created.sil_fc_content.preview_frame.preview.entity = data.main
    player.opened = created.sil_fc_filter_ui
    global.sil_fc_gui[event.player_index] = { ui = created, unit = event.entity.unit_number }
end

--#endregion

local function onEntityPasted(event)
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
local function onEntityCopy(event)
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
        -- Player is editing the blueprint, no access for us yet. Continue this in onBlueprintReady
        if not global.sil_fc_blueprint_data then
            global.sil_fc_blueprint_data = {}
        end
        global.sil_fc_blueprint_data[event.player_index] = result
    end
end

--- @param event EventData.on_player_configured_blueprint
local function onBlueprintReady(event)
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
    local data = locate_config(entity)
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
        create_entity(ent)
        local idx = global.sil_filter_combinators[ent.unit_number]
        local data = global.sil_fc_data[idx]
        data.config = info.cc_config

        local behavior = data.cc.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
        behavior.parameters = info.cc_params
        behavior.enabled = data.config.enabled
        data.ex.get_or_create_control_behavior().enabled = data.config.enabled
        update_entity(data)
    end
    return ent
end

---@param surface LuaSurface
---@param force LuaForce
local function ccs_create_entity(info, surface, force)
    local ent = surface.create_entity { name = const.filter_combinator_name, position = info.position, force = force, direction = info.direction, raise_built = false }
    if ent then
        create_entity(ent)
        local idx = global.sil_filter_combinators[ent.unit_number]
        local data = global.sil_fc_data[idx]
        data.config = info.cc_config

        local behavior = data.cc.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
        behavior.parameters = info.cc_params
        behavior.enabled = data.config.enabled
        data.ex.get_or_create_control_behavior().enabled = data.config.enabled
        update_entity(data)
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
local function on_configuration_changed(changed)
    if changed.mod_changes[const.filter_combinator_name] and changed.mod_changes[const.filter_combinator_name].new_version == '1.0.0' then
        -- Apply second stage of migration
        for _, mig in pairs(global.sil_fc_migration_data) do
            if mig.ent and mig.con then
                local _, ent, __ = mig.ent.silent_revive { raise_revive = true }
                if ent then
                    for _, con in pairs(mig.con) do
                        ent.connect_neighbour(con)
                    end
                else
                    log('Failed to revive ghost on ' .. mig.ent.surface.name .. ' at ' .. serpent.line(mig.ent.position))
                end
            end
        end
        global.sil_fc_migration_data = nil
    else
        global.sil_fc_slot_error_logged = false
        log('Updating for potentially changed signals...')
        for _, data in pairs(global.sil_fc_data) do
            if data and data.ex and data.ex.valid then
                set_all_signals(data.ex)
            end
        end
    end
end

local function housekeeping(event)
    if global.sil_fc_count <= 0 then return end
    for idx, data in pairs(global.sil_fc_data) do
        if not data.main.valid then
            -- most likely cc has removed the main entity
            local ids = data.ids
            -- we ran the migration that created the ids field with all the
            -- combinator ids. Use those
            if ids then
                for id, entity in pairs(ids) do
                    assert(not global.sil_filter_combinators[id] or global.sil_filter_combinators[id] == idx)
                    entity.destroy()
                    global.sil_filter_combinators[id] = nil
                end
            else
                -- remove ids the hard way. Iterate over all known combinators, find the ones
                -- that use the main id.
                for id, main_id in pairs(global.sil_filter_combinators) do
                    if main_id == idx then
                        table.insert(ids, id)
                    end
                end

                -- now kill all the entities in the data object
                data.main.destroy()
                data.cc.destroy()
                data.ex.destroy()
                for _, e in pairs(data.calc) do
                    e.destroy()
                end
            end
            remove_data(idx)
        end
    end
end

script.on_nth_tick(301, housekeeping)

script.on_event(defines.events.on_gui_opened, onGuiOpen)
script.on_event({ defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined, defines.events.on_entity_died }, onEntityDeleted)
script.on_event({ defines.events.on_built_entity, defines.events.on_robot_built_entity, defines.events.script_raised_revive }, onEntityCreated)
script.on_event(defines.events.on_entity_cloned, onEntityCloned)
script.on_event(defines.events.on_entity_settings_pasted, onEntityPasted)

script.on_event(defines.events.on_player_setup_blueprint, onEntityCopy)
script.on_event(defines.events.on_player_configured_blueprint, onBlueprintReady)

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

script.on_configuration_changed(on_configuration_changed)

--- @class FilterCombinatorConfig
--- @field enabled boolean Whether this filter combinator is active
--- @field filter_input_from_wire boolean Whether the signals on the specified wire are used as a filter input
--- @field filter_input_wire defines.wire_type The wire that speficies the signals to filter from the other wire
--- @field exclusive boolean Whether this filter combinator is running in exclusive mode

--- @class FilterCombinatorData
--- @field main LuaEntity
--- @field cc LuaEntity
--- @field calc LuaEntity[]
--- @field ex LuaEntity
--- @field inv LuaEntity
--- @field input_pos LuaEntity
--- @field input_neg LuaEntity
--- @field filter LuaEntity
--- @field inp LuaEntity
--- @field config FilterCombinatorConfig
--- @field ids table<integer, LuaEntity>
