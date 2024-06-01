------------------------------------------------------------------------
--
-- Filter combinator main code
--

local Is = require('__stdlib__/stdlib/utils/is')
local table = require('__stdlib__/stdlib/utils/table')

local const = require('lib.constants')

--- @class FilterCombinator
local FiCo = {}

------------------------------------------------------------------------

---@class FilterCombinatorConfig
---@field enabled boolean
---@field status integer?
---@field use_wire boolean
---@field filter_wire integer
---@field include_mode boolean
---@field signals ConstantCombinatorParameters[]
local default_config = {
    enabled = true,
    use_wire = false,
    filter_wire = defines.wire_type.green,
    include_mode = true,
    signals = {}
}

--- @param parent_config FilterCombinatorConfig?
--- @return FilterCombinatorConfig config
function FiCo:create_config(parent_config)
    parent_config = parent_config or default_config

    local config = {}
    -- iterate over all field names given in the default_config
    for field_name, _ in pairs(default_config) do
        config[field_name] = parent_config[field_name] or default_config[field_name]
    end

    return config
end

------------------------------------------------------------------------

--- Returns the registered total count
--- @return integer count The total count of filter combinators
function FiCo:totalCount()
    return global.fc_data.count
end

--- Returns a map of all entities
--- @return FilterCombinatorData[] entities
function FiCo:entities()
    return global.fc_data.fc
end

--- Returns a map of all entities
--- @return FilterCombinatorData? entity
function FiCo:entity(entity_id)
    return global.fc_data.fc[entity_id]
end

--- Sets or clears a filter combinator entity
--- @param entity_id integer The unit_number of the primary
---@param fc_entity FilterCombinatorData?
function FiCo:setEntity(entity_id, fc_entity)
    assert((fc_entity ~= nil and global.fc_data.fc[entity_id] == nil)
        or (fc_entity == nil and global.fc_data.fc[entity_id] ~= nil))

        if (fc_entity) then
        assert(Is.Valid(fc_entity.main) and fc_entity.main.unit_number == entity_id)
    end

    global.fc_data.fc[entity_id] = fc_entity
    global.fc_data.count = global.fc_data.count + ((fc_entity and 1) or -1)

    if global.fc_data.count < 0 then
        global.fc_data.count = table_size(global.fc_data.fc)
        log('Filter Combinator count got negative (bug), size is now: ' .. global.fc_data.count)
    end
end

------------------------------------------------------------------------

local create_internal_entity

--- Adds a set of signals to the given constant combinator behavior.
--- @param behavior LuaConstantCombinatorControlBehavior
--- @param count integer Number of slots remaining
--- @param prototypes table<string, LuaItemPrototype|LuaFluidPrototype|LuaVirtualSignalPrototype>
--- @param type string name of the type
--- @return boolean success
--- @return integer next_index
local function add_signals(behavior, count, type, prototypes)
    local max = behavior.signals_count
    for sig_name, prototype in pairs(prototypes) do
        if count <= max then
            if not (type == 'virtual' and prototype.special) then
                behavior.set_signal(count, { signal = { type = type, name = sig_name }, count = 1 })
                count = count + 1
            end
        else
            return false, max
        end
    end

    return true, count
end

--- Adds all item, fluid and virtual signals to a combinator.
--- @param behavior LuaConstantCombinatorControlBehavior
local function add_all_signals(behavior)
    local prototypes = {
        item = game.item_prototypes,
        fluid = game.fluid_prototypes,
        virtual = game.virtual_signal_prototypes,
    }
    local idx = 1

    for type, prototype in pairs(prototypes) do
        local success, new_idx = add_signals(behavior, idx, type, prototype)
        if not success then
            Mod.logger:logf('Truncating signal list, too many signals found!')
            break
        else
            idx = new_idx
        end
    end
end

------------------------------------------------------------------------

---@param fc_entity FilterCombinatorData
---@param player_index integer?
---@return LuaEntity all_signals
---@return integer all_signals_count
function FiCo:getAllSignalsConstantCombinator(fc_entity)
    if not Is.Valid(self.all_signals) then
        if (self.all_signals) then
            self.all_signals.destroy()
            self.all_signals = nil
            self.all_signals_count = nil
        end

        if Is.Valid(global.all_signals) then
            self.all_signals = global.all_signals
            self.all_signals_count = global.all_signals_count
        else
            if (global.all_signals) then
                global.all_signals.destroy()
                global.all_signals = nil
                global.all_signals_count = nil
            end

            global.all_signals = create_internal_entity { entity = fc_entity, type = 'cc', ignore = true }
            local all_signals_behavior = global.all_signals.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior ]]
            global.all_signals_count = all_signals_behavior.signals_count
            add_all_signals(all_signals_behavior)

            self.all_signals = global.all_signals
            self.all_signals_count = global.all_signals_count
        end
    end

    return self.all_signals, self.all_signals_count
end

function FiCo:clearAllSignalsConstantCombinator()
    if self.all_signals then
        self.all_signals.destroy()
        self.all_signals = nil
    end
    if global.all_signals then
        global.all_signals.destroy()
        global_all_signals = nil
    end
end

------------------------------------------------------------------------

create_internal_entity = function(cfg)
    local fc_entity = cfg.entity
    local type = cfg.type
    local x = cfg.x or 0
    local y = cfg.y or 0
    local ignore = cfg.ignore or false
    local player_index = cfg.player_index

    -- ignored combinators are always invisible
    local comb_visible = (not ignore) and Mod.settings:player(player_index).comb_visible

    local entity_map = const.entity_maps[comb_visible and 'debug' or 'standard']

    local main = fc_entity.main
    ---@type LuaEntity
    local sub_entity = main.surface.create_entity {
        name = entity_map[type],
        position = { x = main.position.x + (x or 0), y = main.position.y + (y or 0) },
        direction = main.direction,
        force = main.force,

        create_build_effect_smoke = false,
        spawn_decorations = false,
        move_stuck_players = true,
    }

    sub_entity.minable = false
    sub_entity.destructible = false

    if not ignore then
        fc_entity.entities[sub_entity.unit_number] = sub_entity
    end

    return sub_entity
end

------------------------------------------------------------------------

local signal_each = { type = 'virtual', name = 'signal-each' }

local function update_wiring(fc_entity)
    local behavior = function(ref, parameters)
        if parameters.first_signal then
            parameters.first_signal = signal_each
            parameters.output_signal = signal_each
        end
        fc_entity.ref[ref].get_or_create_control_behavior().parameters = parameters
    end

    behavior('ccf', { comparator = '!=', copy_count_from_input = false })
    behavior('d1', { comparator = '<' })
    behavior('d2', { comparator = '>' })
    behavior('d3', { comparator = '>' })
    behavior('d4', { comparator = '<' })
    behavior('a1', { operation = '*', second_constant = 0 - (2 ^ 31 - 1) })
    behavior('a2', { operation = '*', second_constant = -1 })
    behavior('a3', { operation = '*', second_constant = 2 ^ 31 - 1 })
    behavior('a4', { operation = '*', second_constant = -1 })

    behavior('out', { operation = '+', second_constant = 0 })
    behavior('inv', { operation = '*', second_constant = -1 })

    local wire = function(src_ref, src_type, dst_ref, dst_type, wire)
        wire = wire or 'red'
        wire = defines.wire_type[wire]

        fc_entity.ref[src_ref].connect_neighbour {
            target_entity = fc_entity.ref[dst_ref],
            wire = wire,
            source_circuit_id = defines.circuit_connector_id['combinator_' .. src_type],
            target_circuit_id = defines.circuit_connector_id['combinator_' .. dst_type],
        }
    end

    -- ex, target_entity = inv, target_circuit_id = output }
    wire('ex', 'output', 'inv', 'output')
    -- cc, target_entity = inv, target_circuit_id = input }
    wire('cc', 'output', 'inv', 'input')
    -- Exclusive Mode
    -- ccf, target_entity = inv, target_circuit_id = input, source_circuit_id = output, }
    wire('ccf', 'output', 'inv', 'input')

    -- Connect Logic
    -- d1, target_entity = d2, target_circuit_id = input, source_circuit_id = input, }
    wire('d1', 'input', 'd2', 'input')
    -- d1.connect_neighbour { wire = defines.wire_type.green, target_entity = d2, target_circuit_id = input, source_circuit_id = input, }
    wire('d1', 'input', 'd2', 'input', 'green')

    -- -- Negative Inputs
    -- a1, target_entity = cc, source_circuit_id = input }
    wire('a1', 'input', 'cc', 'output')
    -- a2, target_entity = a1, target_circuit_id = output, source_circuit_id = input,}
    wire('a2', 'input', 'a1', 'output')
    -- d3, target_entity = a2, target_circuit_id = output, source_circuit_id = input,}
    wire('d3', 'input', 'a2', 'output')
    -- d3, target_entity = d1, target_circuit_id = output, source_circuit_id = input,}
    wire('d3', 'input', 'd1', 'output')

    -- -- Positive Inputs
    -- a3, target_entity = cc, source_circuit_id = input }
    wire('a3', 'input', 'cc', 'output')
    -- a4, target_entity = a3, target_circuit_id = output, source_circuit_id = input,}
    wire('a4', 'input', 'a3', 'output')
    -- d4, target_entity = a4, target_circuit_id = output, source_circuit_id = input,}
    wire('d4', 'input', 'a4', 'output')
    -- d4, target_entity = d2, target_circuit_id = output, source_circuit_id = input,}
    wire('d4', 'input', 'd2', 'output')

    -- -- Wire up output (to be able to use any color wire again)
    -- out.connect_neighbour { wire = defines.wire_type.green, target_entity = a1, target_circuit_id = output, source_circuit_id = input, }
    wire('out', 'input', 'a1', 'output', 'green')
    -- out.connect_neighbour { wire = defines.wire_type.green, target_entity = d3, target_circuit_id = output, source_circuit_id = input, }
    wire('out', 'input', 'd3', 'output', 'green')
    -- out.connect_neighbour { wire = defines.wire_type.green, target_entity = a3, target_circuit_id = output, source_circuit_id = input, }
    wire('out', 'input', 'a3', 'output', 'green')
    -- out.connect_neighbour { wire = defines.wire_type.green, target_entity = d4, target_circuit_id = output, source_circuit_id = input, }
    wire('out', 'input', 'd4', 'output', 'green')

    -- -- Connect main entity
    -- main, target_entity = out, target_circuit_id = output, source_circuit_id = output, }
    wire('main', 'output', 'out', 'output')
    -- main.connect_neighbour { wire = defines.wire_type.green, target_entity = out, target_circuit_id = output, source_circuit_id = output, }
    wire('main', 'output', 'out', 'output', 'green')
    -- main, target_entity = d1, target_circuit_id = input, source_circuit_id = input, }
    wire('main', 'input', 'd1', 'input')
    -- main.connect_neighbour { wire = defines.wire_type.green, target_entity = d1, target_circuit_id = input, source_circuit_id = input, }
    wire('main', 'input', 'd1', 'input', 'green')
end

--- Creates a new entity from the main entity, registers with the mod
--- and configures it.
--- @param main LuaEntity
--- @param player_index integer?
--- @param tags Tags?
function FiCo:create(main, player_index, tags)
    if not Is.Valid(main) then return end

    local entity_id = main.unit_number --[[@as integer]]

    assert(self:entity(entity_id) == nil)

    local config = self:create_config()

    -- if tags were passed in and they contain a fc config, use that.
    if tags and tags['fc_config'] then
        config = self:create_config(tags['fc_config'] --[[@as FilterCombinatorConfig]])
    end

    local fc_entity = {
        main = main,
        config = table.deepcopy(config), -- config may refer to the signal object in parent or default config.
        entities = { [entity_id] = main, },
        ref = { main = main },
    }
    -- create sub-entities
    for _, cfg in pairs(sub_entities) do
        fc_entity.ref[cfg.id] = create_internal_entity {
            entity = fc_entity,
            type = cfg.type,
            x = cfg.x,
            y = cfg.y,
            player_index = player_index }
    end

    local all_signals = self:getAllSignalsConstantCombinator(fc_entity)
    fc_entity.ref.ex.get_or_create_control_behavior().parameters = all_signals.get_or_create_control_behavior().parameters

    -- setup the wiring of the various sub_entities
    update_wiring(fc_entity)

    self:setEntity(entity_id, fc_entity)

    return fc_entity
end

--     global.sil_filter_combinators[main.unit_number] = main.unit_number

--     local ids = {}
--     ids[main.unit_number] = main

--     local create_internal_entity = function(main, proto)
--         ---@type LuaEntity
--         local ent = main.surface.create_entity {
--             name = proto,
--             position = main.position,
--             direction = main.direction,
--             force = main.force,
--             create_build_effect_smoke = false,
--             spawn_decorations = false,
--             move_stuck_players = true,
--         }

--         global.sil_filter_combinators[ent.unit_number] = main.unit_number
--         ids[ent.unit_number] = ent

--         return ent
--     end

--     --- @type FilterCombinator
--     local conf = get_default_config()

--     -- Logic Circuitry Entities
--     local cc = create_internal_entity(main, const.internal_cc_name)
--     local d1 = create_internal_entity(main, const.internal_dc_name)
--     local d2 = create_internal_entity(main, const.internal_dc_name)
--     local d3 = create_internal_entity(main, const.internal_dc_name)
--     local d4 = create_internal_entity(main, const.internal_dc_name)
--     local a1 = create_internal_entity(main, const.internal_ac_name)
--     local a2 = create_internal_entity(main, const.internal_ac_name)
--     local a3 = create_internal_entity(main, const.internal_ac_name)
--     local a4 = create_internal_entity(main, const.internal_ac_name)
--     local ccf = create_internal_entity(main, const.internal_dc_name)
--     local out = create_internal_entity(main, const.internal_ac_name)
--     local ex = create_internal_entity(main, const.internal_cc_name)
--     local inv = create_internal_entity(main, const.internal_ac_name)

--     -- Check if this was a blueprint which we added custom data to
--     if tags then
--         local behavior = cc.get_or_create_control_behavior()
--         if tags.config ~= nil and tags.params ~= nil then
--             conf = FiCo.add_metatable(tags.config) --[[@as FilterCombinator]]
--             behavior.parameters = tags.params
--         elseif tags.cc_config ~= nil and tags.cc_params ~= nil then
--             -- compakt combinator code uses cc_ for some reason...
--             conf = FiCo.add_metatable(tags.cc_config) --[[@as FilterCombinator]]
--             behavior.parameters = tags.cc_params
--         end
--         behavior.enabled = conf.enabled
--         ex.get_or_create_control_behavior().enabled = conf.enabled
--     end

--     local data = {
--         ids = ids,
--         main = main,
--         cc = cc,
--         calc = { d1, d2, d3, d4, a1, a2, a3, a4, ccf, out, inv },
--         ex = ex,
--         inv = inv,
--         input_pos = a3,
--         input_neg = a1,
--         filter = ccf,
--         inp = d1,
--         config = conf,
--     }

--     -- Set up Exclusive mode Combinator signals
--     FiCo.set_all_signals(ex)
--     -- Set Conditions
--     ccf.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, comparator = '!=', copy_count_from_input = false }
--     out.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, operation = '+', second_constant = 0 }
--     d1.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, comparator = '<' }
--     d2.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, comparator = '>' }
--     a1.get_or_create_control_behavior().parameters = {
--         first_signal = signal_each,
--         output_signal = signal_each,
--         operation = '*',
--         second_constant = 0 -
--             (2 ^ 31 - 1),
--     }
--     a2.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, operation = '*', second_constant = -1 }
--     d3.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, comparator = '>' }
--     a3.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, operation = '*', second_constant = 2 ^ 31 - 1 }
--     a4.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, operation = '*', second_constant = -1 }
--     d4.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, comparator = '<' }
--     inv.get_or_create_control_behavior().parameters = { first_signal = signal_each, output_signal = signal_each, operation = '*', second_constant = -1 }

--     -- Exclusive Mode
--     ex.connect_neighbour { wire = defines.wire_type.red, target_entity = inv, target_circuit_id = defines.circuit_connector_id.combinator_output }
--     cc.connect_neighbour { wire = defines.wire_type.red, target_entity = inv, target_circuit_id = defines.circuit_connector_id.combinator_input }
--     -- Connect Logic
--     ccf.connect_neighbour {
--         wire = defines.wire_type.red,
--         target_entity = inv,
--         target_circuit_id = defines.circuit_connector_id.combinator_input,
--         source_circuit_id =
--             defines.circuit_connector_id.combinator_output,
--     }
--     d1.connect_neighbour {
--         wire = defines.wire_type.red,
--         target_entity = d2,
--         target_circuit_id = defines.circuit_connector_id.combinator_input,
--         source_circuit_id =
--             defines.circuit_connector_id.combinator_input,
--     }
--     d1.connect_neighbour {
--         wire = defines.wire_type.green,
--         target_entity = d2,
--         target_circuit_id = defines.circuit_connector_id.combinator_input,
--         source_circuit_id =
--             defines.circuit_connector_id.combinator_input,
--     }
--     -- Negative Inputs
--     a1.connect_neighbour { wire = defines.wire_type.red, target_entity = cc, source_circuit_id = defines.circuit_connector_id.combinator_input }
--     a2.connect_neighbour {
--         wire = defines.wire_type.red,
--         target_entity = a1,
--         target_circuit_id = defines.circuit_connector_id.combinator_output,
--         source_circuit_id =
--             defines.circuit_connector_id.combinator_input,
--     }
--     d3.connect_neighbour {
--         wire = defines.wire_type.red,
--         target_entity = a2,
--         target_circuit_id = defines.circuit_connector_id.combinator_output,
--         source_circuit_id =
--             defines.circuit_connector_id.combinator_input,
--     }
--     d3.connect_neighbour {
--         wire = defines.wire_type.red,
--         target_entity = d1,
--         target_circuit_id = defines.circuit_connector_id.combinator_output,
--         source_circuit_id =
--             defines.circuit_connector_id.combinator_input,
--     }
--     -- Positive Inputs
--     a3.connect_neighbour { wire = defines.wire_type.red, target_entity = cc, source_circuit_id = defines.circuit_connector_id.combinator_input }
--     a4.connect_neighbour {
--         wire = defines.wire_type.red,
--         target_entity = a3,
--         target_circuit_id = defines.circuit_connector_id.combinator_output,
--         source_circuit_id =
--             defines.circuit_connector_id.combinator_input,
--     }
--     d4.connect_neighbour {
--         wire = defines.wire_type.red,
--         target_entity = a4,
--         target_circuit_id = defines.circuit_connector_id.combinator_output,
--         source_circuit_id =
--             defines.circuit_connector_id.combinator_input,
--     }
--     d4.connect_neighbour {
--         wire = defines.wire_type.red,
--         target_entity = d2,
--         target_circuit_id = defines.circuit_connector_id.combinator_output,
--         source_circuit_id =
--             defines.circuit_connector_id.combinator_input,
--     }
--     -- Wire up output (to be able to use any color wire again)
--     out.connect_neighbour {
--         wire = defines.wire_type.green,
--         target_entity = a1,
--         target_circuit_id = defines.circuit_connector_id.combinator_output,
--         source_circuit_id =
--             defines.circuit_connector_id.combinator_input,
--     }
--     out.connect_neighbour {
--         wire = defines.wire_type.green,
--         target_entity = d3,
--         target_circuit_id = defines.circuit_connector_id.combinator_output,
--         source_circuit_id =
--             defines.circuit_connector_id.combinator_input,
--     }
--     out.connect_neighbour {
--         wire = defines.wire_type.green,
--         target_entity = a3,
--         target_circuit_id = defines.circuit_connector_id.combinator_output,
--         source_circuit_id =
--             defines.circuit_connector_id.combinator_input,
--     }
--     out.connect_neighbour {
--         wire = defines.wire_type.green,
--         target_entity = d4,
--         target_circuit_id = defines.circuit_connector_id.combinator_output,
--         source_circuit_id =
--             defines.circuit_connector_id.combinator_input,
--     }
--     -- Connect main entity
--     main.connect_neighbour {
--         wire = defines.wire_type.red,
--         target_entity = out,
--         target_circuit_id = defines.circuit_connector_id.combinator_output,
--         source_circuit_id =
--             defines.circuit_connector_id.combinator_output,
--     }
--     main.connect_neighbour {
--         wire = defines.wire_type.green,
--         target_entity = out,
--         target_circuit_id = defines.circuit_connector_id.combinator_output,
--         source_circuit_id =
--             defines.circuit_connector_id.combinator_output,
--     }
--     main.connect_neighbour {
--         wire = defines.wire_type.red,
--         target_entity = d1,
--         target_circuit_id = defines.circuit_connector_id.combinator_input,
--         source_circuit_id =
--             defines.circuit_connector_id.combinator_input,
--     }
--     main.connect_neighbour {
--         wire = defines.wire_type.green,
--         target_entity = d1,
--         target_circuit_id = defines.circuit_connector_id.combinator_input,
--         source_circuit_id =
--             defines.circuit_connector_id.combinator_input,
--     }
--     -- Store Entities
--     assert(not global.sil_fc_data[main.unit_number])

--     global.sil_fc_data[main.unit_number] = data
--     global.sil_fc_count = global.sil_fc_count + 1

--     -- check for default config
--     if not (conf.enabled == true and conf.filter_input_from_wire == false and conf.filter_input_wire == defines.wire_type.green and conf.exclusive == false) then
--         data.config:old_update_entity(data)
--     end

--     return data
-- end

---@param fc_entity FilterCombinatorData
function FiCo:update_entity(fc_entity)
    if not fc_entity then return end

    -- update status based on the main entity
    if not Is.Valid(fc_entity.main) then
        fc_entity.config.enabled = false
        fc_entity.config.status = defines.entity_status.marked_for_deconstruction
    else
        fc_entity.config.status = fc_entity.main.status
    end

    -- TODO - rewire/reconfig if needed
end

-- ------------------------------------------------------------------------

function FiCo:destroy(entity_id)
    assert(Is.Number(entity_id))

    local fc_entity = self:entity(entity_id)
    if not fc_entity then return end

    for _, sub_entity in pairs(fc_entity.entities) do
        sub_entity.destroy()
    end

    self:setEntity(entity_id, nil)
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

------------------------------------------------------------------------


--- @param data FilterCombinatorData
function FiCo:old_update_entity(data)
    local non_filter_wire = defines.wire_type.red
    local filter_wire = defines.wire_type.green

    if self.filter_input_wire == defines.wire_type.red then
        non_filter_wire = defines.wire_type.green
        filter_wire = defines.wire_type.red
    end

    -- Disconnect main, which was potentially rewired for wire input based filtering
    data.main.disconnect_neighbour {
        wire = defines.wire_type.red,
        target_entity = data.inp,
        target_circuit_id = defines.circuit_connector_id.combinator_input,
        source_circuit_id =
            defines.circuit_connector_id.combinator_input,
    }
    data.main.disconnect_neighbour {
        wire = defines.wire_type.green,
        target_entity = data.inp,
        target_circuit_id = defines.circuit_connector_id.combinator_input,
        source_circuit_id =
            defines.circuit_connector_id.combinator_input,
    }
    data.main.disconnect_neighbour {
        wire = defines.wire_type.red,
        target_entity = data.filter,
        target_circuit_id = defines.circuit_connector_id
            .combinator_input,
        source_circuit_id = defines.circuit_connector_id.combinator_input,
    }
    data.main.disconnect_neighbour {
        wire = defines.wire_type.green,
        target_entity = data.filter,
        target_circuit_id = defines.circuit_connector_id
            .combinator_input,
        source_circuit_id = defines.circuit_connector_id.combinator_input,
    }

    if not self.enabled then
        -- If disabled nothing else to do after disconnecting main entity
        return
    end

    -- Disconnect configured input, which gets rewired for exclusive mode and wire input filtering
    data.cc.disconnect_neighbour(defines.wire_type.red)
    -- Disconnect inverter, which gets rewired for exclusive mode
    data.inv.disconnect_neighbour {
        wire = defines.wire_type.red,
        target_entity = data.input_pos,
        target_circuit_id = defines.circuit_connector_id
            .combinator_input,
        source_circuit_id = defines.circuit_connector_id.combinator_output,
    }
    data.inv.disconnect_neighbour {
        wire = defines.wire_type.red,
        target_entity = data.input_neg,
        target_circuit_id = defines.circuit_connector_id
            .combinator_input,
        source_circuit_id = defines.circuit_connector_id.combinator_output,
    }
    -- Disconnect filter, which gets rewired for wire input based filtering
    data.filter.disconnect_neighbour {
        wire = defines.wire_type.red,
        target_entity = data.input_pos,
        target_circuit_id = defines.circuit_connector_id
            .combinator_input,
        source_circuit_id = defines.circuit_connector_id.combinator_output,
    }
    data.filter.disconnect_neighbour {
        wire = defines.wire_type.red,
        target_entity = data.input_neg,
        target_circuit_id = defines.circuit_connector_id
            .combinator_input,
        source_circuit_id = defines.circuit_connector_id.combinator_output,
    }

    if self.exclusive and not self.filter_input_from_wire then
        -- All but the configured signals
        data.inv.connect_neighbour {
            wire = defines.wire_type.red,
            target_entity = data.input_pos,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
            source_circuit_id = defines.circuit_connector_id.combinator_output,
        }
        data.inv.connect_neighbour {
            wire = defines.wire_type.red,
            target_entity = data.input_neg,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
            source_circuit_id = defines.circuit_connector_id.combinator_output,
        }
        data.main.connect_neighbour {
            wire = defines.wire_type.red,
            target_entity = data.inp,
            target_circuit_id = defines.circuit_connector_id.combinator_input,
            source_circuit_id =
                defines.circuit_connector_id.combinator_input,
        }
        data.main.connect_neighbour {
            wire = defines.wire_type.green,
            target_entity = data.inp,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
            source_circuit_id = defines.circuit_connector_id.combinator_input,
        }
        data.cc.connect_neighbour { wire = defines.wire_type.red, target_entity = data.inv, target_circuit_id = defines.circuit_connector_id.combinator_input }
    elseif not self.filter_input_from_wire then
        -- Default config
        data.cc.connect_neighbour {
            wire = defines.wire_type.red,
            target_entity = data.input_pos,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
        }
        data.cc.connect_neighbour {
            wire = defines.wire_type.red,
            target_entity = data.input_neg,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
        }
        data.main.connect_neighbour {
            wire = defines.wire_type.red,
            target_entity = data.inp,
            target_circuit_id = defines.circuit_connector_id.combinator_input,
            source_circuit_id =
                defines.circuit_connector_id.combinator_input,
        }
        data.main.connect_neighbour {
            wire = defines.wire_type.green,
            target_entity = data.inp,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
            source_circuit_id = defines.circuit_connector_id.combinator_input,
        }
    elseif self.exclusive then
        -- All but those present on an input wire
        data.main.connect_neighbour {
            wire = non_filter_wire,
            target_entity = data.inp,
            target_circuit_id = defines.circuit_connector_id.combinator_input,
            source_circuit_id =
                defines.circuit_connector_id.combinator_input,
        }
        data.main.connect_neighbour {
            wire = filter_wire,
            target_entity = data.filter,
            target_circuit_id = defines.circuit_connector_id.combinator_input,
            source_circuit_id =
                defines.circuit_connector_id.combinator_input,
        }
        data.inv.connect_neighbour {
            wire = defines.wire_type.red,
            target_entity = data.input_pos,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
            source_circuit_id = defines.circuit_connector_id.combinator_output,
        }
        data.inv.connect_neighbour {
            wire = defines.wire_type.red,
            target_entity = data.input_neg,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
            source_circuit_id = defines.circuit_connector_id.combinator_output,
        }
    else
        -- Wire input is the signals we want
        data.main.connect_neighbour {
            wire = non_filter_wire,
            target_entity = data.inp,
            target_circuit_id = defines.circuit_connector_id.combinator_input,
            source_circuit_id =
                defines.circuit_connector_id.combinator_input,
        }
        data.main.connect_neighbour {
            wire = filter_wire,
            target_entity = data.filter,
            target_circuit_id = defines.circuit_connector_id.combinator_input,
            source_circuit_id =
                defines.circuit_connector_id.combinator_input,
        }
        data.filter.connect_neighbour {
            wire = defines.wire_type.red,
            target_entity = data.input_pos,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
            source_circuit_id = defines.circuit_connector_id.combinator_output,
        }
        data.filter.connect_neighbour {
            wire = defines.wire_type.red,
            target_entity = data.input_neg,
            target_circuit_id = defines.circuit_connector_id
                .combinator_input,
            source_circuit_id = defines.circuit_connector_id.combinator_output,
        }
    end
end

---@param table FilterCombinator
---@return table FilterCombinator
function FiCo.add_metatable(table)
    if not getmetatable(table) then
        setmetatable(table, { __index = FiCo })
    end
    return table
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
--- @field config FilterCombinatorConfig
--- @field entities LuaEntity[]
--- @field ref table<string, LuaEntity>
