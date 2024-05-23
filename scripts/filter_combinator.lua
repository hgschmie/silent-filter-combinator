--
-- Filter combinator main code
--

local const = require('lib.constants')

--- @class FilterCombinatorConfig
--- @field enabled boolean Whether this filter combinator is active
--- @field filter_input_from_wire boolean Whether the signals on the specified wire are used as a filter input
--- @field filter_input_wire defines.wire_type The wire that speficies the signals to filter from the other wire
--- @field exclusive boolean Whether this filter combinator is running in exclusive mode
local FiCo = {
    --[[ Constants]]
    VERSION = 1,
    --[[ Instance Fields ]]
    enabled = true,
    filter_input_from_wire = false,
    filter_input_wire = defines.wire_type.green,
    exclusive = false,
}

local signal_each = { type = 'virtual', name = 'signal-each' }

------------------------------------------------------------------------

--- @return FilterCombinatorConfig default_config
local function get_default_config()
    return FiCo.add_metatable({
        enabled = true,
        filter_input_from_wire = false,
        filter_input_wire = defines.wire_type.green,
        exclusive = false,
    })
end

--- @param comb LuaEntity
function FiCo.set_all_signals(comb)
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

---Returns the filter combinator configuration or nil
---@param entity LuaEntity|integer
---@return FilterCombinatorData? config The filter combinator configuration
---@return integer match The index in the data array
function FiCo.locate_config(entity)
    local id = entity
    if type(entity) == 'table' then
        if not (entity and entity.valid) then return nil, -1 end
        id = entity.unit_number
    end

    local match = global.sil_filter_combinators[id]
    if not match then return nil, -1 end
    return global.sil_fc_data[match], match
end

--- @param unit_number integer
function FiCo:remove_data(unit_number)
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

------------------------------------------------------------------------


--- @param data FilterCombinatorData
function FiCo:update_entity(data)
    local non_filter_wire = defines.wire_type.red
    local filter_wire = defines.wire_type.green

    if self.filter_input_wire == defines.wire_type.red then
        non_filter_wire = defines.wire_type.green
        filter_wire = defines.wire_type.red
    end

    -- Disconnect main, which was potentially rewired for wire input based filtering
    data.main.disconnect_neighbour({
        wire = defines.wire_type.red,
        target_entity = data.inp,
        target_circuit_id = defines.circuit_connector_id.combinator_input,
        source_circuit_id =
            defines.circuit_connector_id.combinator_input,
    })
    data.main.disconnect_neighbour({
        wire = defines.wire_type.green,
        target_entity = data.inp,
        target_circuit_id = defines.circuit_connector_id.combinator_input,
        source_circuit_id =
            defines.circuit_connector_id.combinator_input,
    })
    data.main.disconnect_neighbour({
        wire = defines.wire_type.red,
        target_entity = data.filter,
        target_circuit_id = defines.circuit_connector_id
            .combinator_input,
        source_circuit_id = defines.circuit_connector_id.combinator_input,
    })
    data.main.disconnect_neighbour({
        wire = defines.wire_type.green,
        target_entity = data.filter,
        target_circuit_id = defines.circuit_connector_id
            .combinator_input,
        source_circuit_id = defines.circuit_connector_id.combinator_input,
    })

    if not self.enabled then
        -- If disabled nothing else to do after disconnecting main entity
        return
    end

    -- Disconnect configured input, which gets rewired for exclusive mode and wire input filtering
    data.cc.disconnect_neighbour(defines.wire_type.red)
    -- Disconnect inverter, which gets rewired for exclusive mode
    data.inv.disconnect_neighbour({
        wire = defines.wire_type.red,
        target_entity = data.input_pos,
        target_circuit_id = defines.circuit_connector_id
            .combinator_input,
        source_circuit_id = defines.circuit_connector_id.combinator_output,
    })
    data.inv.disconnect_neighbour({
        wire = defines.wire_type.red,
        target_entity = data.input_neg,
        target_circuit_id = defines.circuit_connector_id
            .combinator_input,
        source_circuit_id = defines.circuit_connector_id.combinator_output,
    })
    -- Disconnect filter, which gets rewired for wire input based filtering
    data.filter.disconnect_neighbour({
        wire = defines.wire_type.red,
        target_entity = data.input_pos,
        target_circuit_id = defines.circuit_connector_id
            .combinator_input,
        source_circuit_id = defines.circuit_connector_id.combinator_output,
    })
    data.filter.disconnect_neighbour({
        wire = defines.wire_type.red,
        target_entity = data.input_neg,
        target_circuit_id = defines.circuit_connector_id
            .combinator_input,
        source_circuit_id = defines.circuit_connector_id.combinator_output,
    })

    if self.exclusive and not self.filter_input_from_wire then
        -- All but the configured signals
        data.inv.connect_neighbour({
            wire = defines.wire_type.red,
            target_entity = data.input_pos,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
            source_circuit_id = defines.circuit_connector_id.combinator_output,
        })
        data.inv.connect_neighbour({
            wire = defines.wire_type.red,
            target_entity = data.input_neg,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
            source_circuit_id = defines.circuit_connector_id.combinator_output,
        })
        data.main.connect_neighbour({
            wire = defines.wire_type.red,
            target_entity = data.inp,
            target_circuit_id = defines.circuit_connector_id.combinator_input,
            source_circuit_id =
                defines.circuit_connector_id.combinator_input,
        })
        data.main.connect_neighbour({
            wire = defines.wire_type.green,
            target_entity = data.inp,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
            source_circuit_id = defines.circuit_connector_id.combinator_input,
        })
        data.cc.connect_neighbour({ wire = defines.wire_type.red, target_entity = data.inv, target_circuit_id = defines.circuit_connector_id.combinator_input })
    elseif not self.filter_input_from_wire then
        -- Default config
        data.cc.connect_neighbour({
            wire = defines.wire_type.red,
            target_entity = data.input_pos,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
        })
        data.cc.connect_neighbour({
            wire = defines.wire_type.red,
            target_entity = data.input_neg,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
        })
        data.main.connect_neighbour({
            wire = defines.wire_type.red,
            target_entity = data.inp,
            target_circuit_id = defines.circuit_connector_id.combinator_input,
            source_circuit_id =
                defines.circuit_connector_id.combinator_input,
        })
        data.main.connect_neighbour({
            wire = defines.wire_type.green,
            target_entity = data.inp,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
            source_circuit_id = defines.circuit_connector_id.combinator_input,
        })
    elseif self.exclusive then
        -- All but those present on an input wire
        data.main.connect_neighbour({
            wire = non_filter_wire,
            target_entity = data.inp,
            target_circuit_id = defines.circuit_connector_id.combinator_input,
            source_circuit_id =
                defines.circuit_connector_id.combinator_input,
        })
        data.main.connect_neighbour({
            wire = filter_wire,
            target_entity = data.filter,
            target_circuit_id = defines.circuit_connector_id.combinator_input,
            source_circuit_id =
                defines.circuit_connector_id.combinator_input,
        })
        data.inv.connect_neighbour({
            wire = defines.wire_type.red,
            target_entity = data.input_pos,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
            source_circuit_id = defines.circuit_connector_id.combinator_output,
        })
        data.inv.connect_neighbour({
            wire = defines.wire_type.red,
            target_entity = data.input_neg,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
            source_circuit_id = defines.circuit_connector_id.combinator_output,
        })
    else
        -- Wire input is the signals we want
        data.main.connect_neighbour({
            wire = non_filter_wire,
            target_entity = data.inp,
            target_circuit_id = defines.circuit_connector_id.combinator_input,
            source_circuit_id =
                defines.circuit_connector_id.combinator_input,
        })
        data.main.connect_neighbour({
            wire = filter_wire,
            target_entity = data.filter,
            target_circuit_id = defines.circuit_connector_id.combinator_input,
            source_circuit_id =
                defines.circuit_connector_id.combinator_input,
        })
        data.filter.connect_neighbour({
            wire = defines.wire_type.red,
            target_entity = data.input_pos,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
            source_circuit_id = defines.circuit_connector_id.combinator_output,
        })
        data.filter.connect_neighbour({
            wire = defines.wire_type.red,
            target_entity = data.input_neg,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
            source_circuit_id = defines.circuit_connector_id.combinator_output,
        })
    end
end

---@param table FilterCombinatorConfig
---@return table FilterCombinatorConfig
function FiCo.add_metatable(table)
    if not getmetatable(table) then
        setmetatable(table, { __index = FiCo })
    end
    return table
end

--- @param main LuaEntity
--- @param tags Tags?
function FiCo.create_entity(main, tags)
    if not (main and main.valid and (main.name == const.filter_combinator_name or main.name == const.filter_combinator_name_packed)) then return end

    global.sil_filter_combinators[main.unit_number] = main.unit_number

    local ids = {}
    ids[main.unit_number] = main

    local create_internal_entity = function(main, proto)
        ---@type LuaEntity
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

    -- Check if this was a blueprint which we added custom data to
    if tags then
        local behavior = cc.get_or_create_control_behavior()
        if tags.config ~= nil and tags.params ~= nil then
            conf = FiCo.add_metatable(tags.config) --[[@as FilterCombinatorConfig]]
            behavior.parameters = tags.params
        elseif tags.cc_config ~= nil and tags.cc_params ~= nil then
            -- compakt combinator code uses cc_ for some reason...
            conf = FiCo.add_metatable(tags.cc_config) --[[@as FilterCombinatorConfig]]
            behavior.parameters = tags.cc_params
        end
        behavior.enabled = conf.enabled
        ex.get_or_create_control_behavior().enabled = conf.enabled
    end

    local data = {
        ids = ids,
        main = main,
        cc = cc,
        calc = { d1, d2, d3, d4, a1, a2, a3, a4, ccf, out, inv },
        ex = ex,
        inv = inv,
        input_pos = a3,
        input_neg = a1,
        filter = ccf,
        inp = d1,
        config = conf,
    }

    -- Set up Exclusive mode Combinator signals
    FiCo.set_all_signals(ex)
    -- Set Conditions
    ccf.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, comparator = '!=', copy_count_from_input = false }
    out.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, operation = '+', second_constant = 0 }
    d1.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, comparator = '<' }
    d2.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, comparator = '>' }
    a1.get_or_create_control_behavior().parameters = {
        first_signal = signal_each,
        output_signal = signal_each,
        operation = '*',
        second_constant = 0 -
            (2 ^ 31 - 1),
    }
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
    ccf.connect_neighbour({
        wire = defines.wire_type.red,
        target_entity = inv,
        target_circuit_id = defines.circuit_connector_id.combinator_input,
        source_circuit_id =
            defines.circuit_connector_id.combinator_output,
    })
    d1.connect_neighbour({
        wire = defines.wire_type.red,
        target_entity = d2,
        target_circuit_id = defines.circuit_connector_id.combinator_input,
        source_circuit_id =
            defines.circuit_connector_id.combinator_input,
    })
    d1.connect_neighbour({
        wire = defines.wire_type.green,
        target_entity = d2,
        target_circuit_id = defines.circuit_connector_id.combinator_input,
        source_circuit_id =
            defines.circuit_connector_id.combinator_input,
    })
    -- Negative Inputs
    a1.connect_neighbour({ wire = defines.wire_type.red, target_entity = cc, source_circuit_id = defines.circuit_connector_id.combinator_input })
    a2.connect_neighbour({
        wire = defines.wire_type.red,
        target_entity = a1,
        target_circuit_id = defines.circuit_connector_id.combinator_output,
        source_circuit_id =
            defines.circuit_connector_id.combinator_input,
    })
    d3.connect_neighbour({
        wire = defines.wire_type.red,
        target_entity = a2,
        target_circuit_id = defines.circuit_connector_id.combinator_output,
        source_circuit_id =
            defines.circuit_connector_id.combinator_input,
    })
    d3.connect_neighbour({
        wire = defines.wire_type.red,
        target_entity = d1,
        target_circuit_id = defines.circuit_connector_id.combinator_output,
        source_circuit_id =
            defines.circuit_connector_id.combinator_input,
    })
    -- Positive Inputs
    a3.connect_neighbour({ wire = defines.wire_type.red, target_entity = cc, source_circuit_id = defines.circuit_connector_id.combinator_input })
    a4.connect_neighbour({
        wire = defines.wire_type.red,
        target_entity = a3,
        target_circuit_id = defines.circuit_connector_id.combinator_output,
        source_circuit_id =
            defines.circuit_connector_id.combinator_input,
    })
    d4.connect_neighbour({
        wire = defines.wire_type.red,
        target_entity = a4,
        target_circuit_id = defines.circuit_connector_id.combinator_output,
        source_circuit_id =
            defines.circuit_connector_id.combinator_input,
    })
    d4.connect_neighbour({
        wire = defines.wire_type.red,
        target_entity = d2,
        target_circuit_id = defines.circuit_connector_id.combinator_output,
        source_circuit_id =
            defines.circuit_connector_id.combinator_input,
    })
    -- Wire up output (to be able to use any color wire again)
    out.connect_neighbour({
        wire = defines.wire_type.green,
        target_entity = a1,
        target_circuit_id = defines.circuit_connector_id.combinator_output,
        source_circuit_id =
            defines.circuit_connector_id.combinator_input,
    })
    out.connect_neighbour({
        wire = defines.wire_type.green,
        target_entity = d3,
        target_circuit_id = defines.circuit_connector_id.combinator_output,
        source_circuit_id =
            defines.circuit_connector_id.combinator_input,
    })
    out.connect_neighbour({
        wire = defines.wire_type.green,
        target_entity = a3,
        target_circuit_id = defines.circuit_connector_id.combinator_output,
        source_circuit_id =
            defines.circuit_connector_id.combinator_input,
    })
    out.connect_neighbour({
        wire = defines.wire_type.green,
        target_entity = d4,
        target_circuit_id = defines.circuit_connector_id.combinator_output,
        source_circuit_id =
            defines.circuit_connector_id.combinator_input,
    })
    -- Connect main entity
    main.connect_neighbour({
        wire = defines.wire_type.red,
        target_entity = out,
        target_circuit_id = defines.circuit_connector_id.combinator_output,
        source_circuit_id =
            defines.circuit_connector_id.combinator_output,
    })
    main.connect_neighbour({
        wire = defines.wire_type.green,
        target_entity = out,
        target_circuit_id = defines.circuit_connector_id.combinator_output,
        source_circuit_id =
            defines.circuit_connector_id.combinator_output,
    })
    main.connect_neighbour({
        wire = defines.wire_type.red,
        target_entity = d1,
        target_circuit_id = defines.circuit_connector_id.combinator_input,
        source_circuit_id =
            defines.circuit_connector_id.combinator_input,
    })
    main.connect_neighbour({
        wire = defines.wire_type.green,
        target_entity = d1,
        target_circuit_id = defines.circuit_connector_id.combinator_input,
        source_circuit_id =
            defines.circuit_connector_id.combinator_input,
    })
    -- Store Entities
    assert(not global.sil_fc_data[main.unit_number])

    global.sil_fc_data[main.unit_number] = data
    global.sil_fc_count = global.sil_fc_count + 1

    -- check for default config
    if not (conf.enabled == true and conf.filter_input_from_wire == false and conf.filter_input_wire == defines.wire_type.green and conf.exclusive == false) then
        data.config:update_entity(data)
    end

    return data
end

--- @param entity LuaEntity
function FiCo.delete_entity(entity)
    if string.sub(entity.name, 1, const.name_prefix_len) ~= const.filter_combinator_name then return end

    local data, match = FiCo.locate_config(entity)
    if not data then return end

    assert(data.main.valid and entity.valid and data.main.unit_number == entity.unit_number)

    for idx, entity in pairs(data.ids) do
        entity.destroy()
        global.sil_filter_combinators[idx] = nil
    end

    FiCo.add_metatable(data.config):remove_data(match)
end

function FiCo.move_entity(entity)
    local data = FiCo.locate_config(entity)
    if data then
        for _, e in pairs(data.ids) do
            if e.valid then
                e.teleport(entity.position)
            end
        end
    end
end

function FiCo.clone_entity(src, dst)
    local data = FiCo.locate_config(src)
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

return FiCo

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
