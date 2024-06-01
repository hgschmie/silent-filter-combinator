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

--- Returns data for all filter combinators.
--- @return FilterCombinatorData[] entities
function FiCo:entities()
    return global.fc_data.fc
end

--- Returns data for a given filter combinator
--- @param entity_id integer main unit number (== entity id)
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

local initial_behavior = {
    { src = 'filter',    comparator = '!=', copy_count_from_input = false },
    { src = 'inp',       comparator = '<' },
    { src = 'd2',        comparator = '>' },
    { src = 'd3',        comparator = '>' },
    { src = 'd4',        comparator = '<' },
    { src = 'input_neg', operation = '*',   second_constant = 0 - (2 ^ 31 - 1) },
    { src = 'a2',        operation = '*',   second_constant = -1 },
    { src = 'input_pos', operation = '*',   second_constant = 2 ^ 31 - 1 },
    { src = 'a4',        operation = '*',   second_constant = -1 },
    { src = 'out',       operation = '+',   second_constant = 0 },
    { src = 'inv',       operation = '*',   second_constant = -1 },
}

local wiring = {
    initial = {
        -- ex, target_entity = inv, target_circuit_id = output }
        { src = 'ex',        dst = 'inv',            dst_circuit = 'output' },
        -- cc, target_entity = inv, target_circuit_id = input }
        { src = 'cc',        dst = 'inv',            dst_circuit = 'input' },
        -- Exclusive Mode
        -- ccf, target_entity = inv, target_circuit_id = input, source_circuit_id = output, }
        { src = 'filter',    src_circuit = 'output', dst = 'inv',           dst_circuit = 'input' },

        -- Connect Logic
        -- d1, target_entity = d2, target_circuit_id = input, source_circuit_id = input, }
        { src = 'inp',       src_circuit = 'input',  dst = 'd2',            dst_circuit = 'input' },
        -- d1.connect_neighbour { wire = defines.wire_type.green, target_entity = d2, target_circuit_id = input, source_circuit_id = input, }
        { src = 'inp',       src_circuit = 'input',  dst = 'd2',            dst_circuit = 'input',  wire = 'green' },

        -- -- Negative Inputs
        -- a1, target_entity = cc, source_circuit_id = input }
        { src = 'input_neg', src_circuit = 'input',  dst = 'cc' },
        -- a2, target_entity = a1, target_circuit_id = output, source_circuit_id = input,}
        { src = 'a2',        src_circuit = 'input',  dst = 'input_neg',     dst_circuit = 'output' },
        -- d3, target_entity = a2, target_circuit_id = output, source_circuit_id = input,}
        { src = 'd3',        src_circuit = 'input',  dst = 'a2',            dst_circuit = 'output' },
        -- d3, target_entity = d1, target_circuit_id = output, source_circuit_id = input,}
        { src = 'd3',        src_circuit = 'input',  dst = 'inp',           dst_circuit = 'output' },

        -- -- Positive Inputs
        -- a3, target_entity = cc, source_circuit_id = input }
        { src = 'input_pos', src_circuit = 'input',  dst = 'cc' },
        -- a4, target_entity = a3, target_circuit_id = output, source_circuit_id = input,}
        { src = 'a4',        src_circuit = 'input',  dst = 'input_pos',     dst_circuit = 'output' },
        -- d4, target_entity = a4, target_circuit_id = output, source_circuit_id = input,}
        { src = 'd4',        src_circuit = 'input',  dst = 'a4',            dst_circuit = 'output' },
        -- d4, target_entity = d2, target_circuit_id = output, source_circuit_id = input,}
        { src = 'd4',        src_circuit = 'input',  dst = 'd2',            dst_circuit = 'output' },

        -- -- Wire up output (to be able to use any color wire again)
        -- out.connect_neighbour { wire = defines.wire_type.green, target_entity = a1, target_circuit_id = output, source_circuit_id = input, }
        { src = 'out',       src_circuit = 'input',  dst = 'input_neg',     dst_circuit = 'output', wire = 'green' },
        -- out.connect_neighbour { wire = defines.wire_type.green, target_entity = d3, target_circuit_id = output, source_circuit_id = input, }
        { src = 'out',       src_circuit = 'input',  dst = 'd3',            dst_circuit = 'output', 'green' },
        -- out.connect_neighbour { wire = defines.wire_type.green, target_entity = a3, target_circuit_id = output, source_circuit_id = input, }
        { src = 'out',       src_circuit = 'input',  dst = 'input_pos',     dst_circuit = 'output', wire = 'green' },
        -- out.connect_neighbour { wire = defines.wire_type.green, target_entity = d4, target_circuit_id = output, source_circuit_id = input, }
        { src = 'out',       src_circuit = 'input',  dst = 'd4',            dst_circuit = 'output', wire = 'green' },

        -- -- Connect main entity
        -- main, target_entity = out, target_circuit_id = output, source_circuit_id = output, }
        { src = 'main',      src_circuit = 'output', dst = 'out',           dst_circuit = 'output' },
        -- main.connect_neighbour { wire = defines.wire_type.green, target_entity = out, target_circuit_id = output, source_circuit_id = output, }
        { src = 'main',      src_circuit = 'output', dst = 'out',           dst_circuit = 'output', wire = 'green' },
        -- main, target_entity = d1, target_circuit_id = input, source_circuit_id = input, }
        { src = 'main',      src_circuit = 'input',  dst = 'inp',           dst_circuit = 'input' },
        -- main.connect_neighbour { wire = defines.wire_type.green, target_entity = d1, target_circuit_id = input, source_circuit_id = input, }
        { src = 'main',      src_circuit = 'input',  dst = 'inp',           dst_circuit = 'input',  wire = 'green' },
    },
    disconnect1 = {
        -- Disconnect main, which was potentially rewired for wire input based filtering
        -- data.main.disconnect_neighbour { wire = defines.wire_type.red, target_entity = data.inp, target=input, source=input, }
        { src = 'main', src_circuit = 'input', dst = 'inp',    dst_circuit = 'input' },
        -- data.main.disconnect_neighbour { wire = defines.wire_type.green, target_entity = data.inp, target=input, source=input, }
        { src = 'main', src_circuit = 'input', dst = 'inp',    dst_circuit = 'input', wire = 'green' },
        -- data.main.disconnect_neighbour { wire = defines.wire_type.red, target_entity = data.filter, target=input, source=input, }
        { src = 'main', src_circuit = 'input', dst = 'filter', dst_circuit = 'input' },
        -- data.main.disconnect_neighbour { wire = defines.wire_type.green, target_entity = data.filter, target=input, source=input, }
        { src = 'main', src_circuit = 'input', dst = 'filter', dst_circuit = 'input', wire = 'green' },
    },
    disconnect2 = {
        -- Disconnect configured input, which gets rewired for exclusive mode and wire input filtering
        -- data.cc.disconnect_neighbour(defines.wire_type.red)
        { src = 'cc' },

        -- Disconnect inverter, which gets rewired for exclusive mode
        -- data.inv.disconnect_neighbour { wire = defines.wire_type.red, target_entity = data.input_pos, target=input, source=output, }
        { src = 'inv',    src_circuit = 'output', dst = 'input_pos', dst_circuit = 'input' },
        -- data.inv.disconnect_neighbour { wire = defines.wire_type.red, target_entity = data.input_neg, target=input, source=output, }
        { src = 'inv',    src_circuit = 'output', dst = 'input_neg', dst_circuit = 'input' },

        -- Disconnect filter, which gets rewired for wire input based filtering
        -- data.filter.disconnect_neighbour { wire = defines.wire_type.red, target_entity = data.input_pos, target=input, source=output, }
        { src = 'filter', src_circuit = 'output', dst = 'input_pos', dst_circuit = 'input' },
        -- data.filter.disconnect_neighbour { wire = defines.wire_type.red, target_entity = data.input_neg, target=input, source=output, }
        { src = 'filter', src_circuit = 'output', dst = 'input_neg', dst_circuit = 'input' },

    },
    connect_default = {
        -- Default config
        -- data.cc.connect_neighbour { wire = defines.wire_type.red, target_entity = data.input_pos, target=input, }
        { src = 'cc',   dst = 'input_pos',     dst_circuit = 'input' },
        -- data.cc.connect_neighbour { wire = defines.wire_type.red, target_entity = data.input_neg, target=input, }
        { src = 'cc',   dst = 'input_neg',     dst_circuit = 'input' },

        -- data.main.connect_neighbour { wire = defines.wire_type.red, target_entity = data.inp, target=input, source=input, }
        { src = 'main', src_circuit = 'input', dst = 'inp',          dst_circuit = 'input' },
        -- data.main.connect_neighbour { wire = defines.wire_type.green, target_entity = data.inp, target=input, source=input, }
        { src = 'main', src_circuit = 'input', dst = 'inp',          dst_circuit = 'input', wire = 'green' },
    },
    connect_exclude = {
        -- All but the configured signals
        -- data.cc.connect_neighbour { wire = defines.wire_type.red, target_entity = data.inv, target=input }
        { src = 'cc',   dst = 'inv',            dst_circuit = 'input' },

        -- data.inv.connect_neighbour { wire = defines.wire_type.red, target_entity = data.input_pos, target=input, source=output, }
        { src = 'inv',  src_circuit = 'output', dst = 'input_pos',    dst_circuit = 'input' },
        -- data.inv.connect_neighbour { wire = defines.wire_type.red, target_entity = data.input_neg, target=input, source=output, }
        { src = 'inv',  src_circuit = 'output', dst = 'input_neg',    dst_circuit = 'input' },

        -- data.main.connect_neighbour { wire = defines.wire_type.red, target_entity = data.inp, target=input, source=input, }
        { src = 'main', src_circuit = 'input',  dst = 'inp',          dst_circuit = 'input' },
        -- data.main.connect_neighbour { wire = defines.wire_type.green, target_entity = data.inp, target=input, source=input, }
        { src = 'main', src_circuit = 'input',  dst = 'inp',          dst_circuit = 'input', wire = 'green' },
    },
    connect_use_wire = {
        -- Wire input is the signals we want
        -- data.main.connect_neighbour { wire = non_filter_wire, target_entity = data.inp, target=input, source=input, }
        { src = 'main',   src_circuit = 'input',  dst = 'inp',       dst_circuit = 'input', wire = 'non_filter' },
        -- data.main.connect_neighbour { wire = filter_wire, target_entity = data.filter, target=input, source=input, }
        { src = 'main',   src_circuit = 'input',  dst = 'filter',    dst_circuit = 'input', wire = 'filter' },

        -- data.filter.connect_neighbour { wire = defines.wire_type.red, target_entity = data.input_pos, target=input, source=output, }
        { src = 'filter', src_circuit = 'output', dst = 'input_pos', dst_circuit = 'input' },
        -- data.filter.connect_neighbour { wire = defines.wire_type.red, target_entity = data.input_neg, target=input, source=output, }
        { src = 'filter', src_circuit = 'output', dst = 'input_neg', dst_circuit = 'input' },

    },
    connect_use_wire_exclude = {
        -- All but those present on an input wire
        -- data.main.connect_neighbour { wire = non_filter_wire, target_entity = data.inp, target=input, source=input, }
        { src = 'main', src_circuit = 'input',  dst = 'inp',       dst_circuit = 'input', wire = 'non_filter' },
        -- data.main.connect_neighbour { wire = filter_wire, target_entity = data.filter, target=input, source=input, }
        { src = 'main', src_circuit = 'input',  dst = 'filter',    dst_circuit = 'input', wire = 'filter' },

        -- data.inv.connect_neighbour { wire = defines.wire_type.red, target_entity = data.input_pos, target=input, source=output, }
        { src = 'inv',  src_circuit = 'output', dst = 'input_pos', dst_circuit = 'input' },
        -- data.inv.connect_neighbour { wire = defines.wire_type.red, target_entity = data.input_neg, target=input, source=output, }
        { src = 'inv',  src_circuit = 'output', dst = 'input_neg', dst_circuit = 'input' },
    }
}


---@class FcWireConfig
---@field src string
---@field dst string?
---@field src_circuit string?
---@field dst_circuit string?
---@field wire string?


---@param fc_entity FilterCombinatorData
---@param wire_cfg FcWireConfig
---@param wire_type table<string, defines.wire_type>?
local function connect_wire(fc_entity, wire_cfg, wire_type)
    wire_type = wire_type or defines.wire_type
    local wire = wire_type[wire_cfg.wire or 'red']

    assert(fc_entity.ref[wire_cfg.src])
    assert(fc_entity.ref[wire_cfg.dst])

    assert(fc_entity.ref[wire_cfg.src].connect_neighbour {
        target_entity = fc_entity.ref[wire_cfg.dst],
        wire = wire,
        source_circuit_id = wire_cfg.src_circuit and defines.circuit_connector_id['combinator_' .. wire_cfg.src_circuit],
        target_circuit_id = wire_cfg.dst_circuit and defines.circuit_connector_id['combinator_' .. wire_cfg.dst_circuit],
    })
end

---@param fc_entity FilterCombinatorData
---@param wire_cfg FcWireConfig
local function disconnect_wire(fc_entity, wire_cfg)
    local wire = defines.wire_type[wire_cfg.wire or 'red']

    assert(fc_entity.ref[wire_cfg.src])
    if wire_cfg.dst then
        assert(fc_entity.ref[wire_cfg.dst])
    end

    if wire_cfg.dst then
        fc_entity.ref[wire_cfg.src].disconnect_neighbour {
            target_entity = fc_entity.ref[wire_cfg.dst],
            wire = wire,
            source_circuit_id = wire_cfg.src_circuit and defines.circuit_connector_id['combinator_' .. wire_cfg.src_circuit],
            target_circuit_id = wire_cfg.dst_circuit and defines.circuit_connector_id['combinator_' .. wire_cfg.dst_circuit],
        }
    else
        fc_entity.ref[wire_cfg.src].disconnect_neighbour(wire)
    end
end


--
--    -4/-4  -2/-4   0/-4   2/-4   4/-4
--    -4/-2  -2/-2   0/-2   2/-2   4/-2
--    -4/ 0  -2/ 0   0/ 0   2/ 0   4/ 0
--    -4/ 2  -2/ 2   0/ 2   2/ 2   4/ 2
--    -4/ 4  -2/ 4   0/ 4   2/ 4   4/ 4
--
local sub_entities = {
    { id = 'cc',        type = 'cc', x = -4, y = 4 },
    { id = 'ex',        type = 'cc', x = 4,  y = 4 },

    { id = 'filter',    type = 'dc', x = -2, y = 2 },

    { id = 'inp',       type = 'dc', x = 0,  y = 4 },
    { id = 'out',       type = 'ac', x = 0,  y = -4 },

    { id = 'inv',       type = 'ac', x = 2,  y = 2 },

    { id = 'input_pos', type = 'ac', x = -2, y = 0 },
    { id = 'input_neg', type = 'ac', x = 2,  y = 0 },

    { id = 'a2',        type = 'ac', x = -4, y = -2 },
    { id = 'a4',        type = 'ac', x = -2, y = -2 },

    { id = 'd2',        type = 'dc', x = 0,  y = -2 },
    { id = 'd3',        type = 'dc', x = 2,  y = -2 },
    { id = 'd4',        type = 'dc', x = 4,  y = -2 },

}

------------------------------------------------------------------------

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

    -- setup all the sub-entities
    for _, behavior in pairs(initial_behavior) do
        local parameters = {
            first_signal = behavior.first_signal or signal_each,
            output_signal = behavior.output_signal or signal_each,
            comparator = behavior.comparator,
            operation = behavior.operation,
            copy_count_from_input = behavior.copy_count_from_input,
            second_constant = behavior.second_constant
        }
        fc_entity.ref[behavior.src].get_or_create_control_behavior().parameters = parameters
    end

    -- setup the initial wiring
    for _, connect in pairs(wiring.initial) do
        connect_wire(fc_entity, connect)
    end

    self:setEntity(entity_id, fc_entity)

    return fc_entity
end

------------------------------------------------------------------------

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
end

------------------------------------------------------------------------

---@param fc_entity FilterCombinatorData
function FiCo:rewire_entity(fc_entity)
    if not fc_entity then return end

    local fc_config = fc_entity.config

    for _, cfg in pairs(wiring.disconnect1) do
        disconnect_wire(fc_entity, cfg)
    end

    -- turn main entity and the constant combinators on or off
    fc_entity.ref.main.active = fc_config.enabled
    fc_entity.ref.ex.get_or_create_control_behavior().enabled = fc_config.enabled

    local cc_control = fc_entity.ref.cc.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior ]]
    cc_control.enabled = fc_config.enabled
    cc_control.parameters = table.deepcopy(fc_config.signals)

    if not fc_config.enabled then return end

    for _, cfg in pairs(wiring.disconnect2) do
        disconnect_wire(fc_entity, cfg)
    end

    local rewire_cfg
    if fc_config.include_mode and fc_config.use_wire then
        -- all inputs on a wire
        rewire_cfg = wiring.connect_use_wire
    elseif fc_config.use_wire then
        -- all but inputs on a wire
        rewire_cfg = wiring.connect_use_wire_exclude
    elseif fc_config.include_mode then
        -- default
        rewire_cfg = wiring.connect_default
    else
        -- exclude mode
        rewire_cfg = wiring.connect_exclude
    end

    local wire_type = {
        red = defines.wire_type.red,
        green = defines.wire_type.green,
        filter = fc_config.filter_wire == defines.wire_type.red and defines.wire_type.red or defines.wire_type.green,
        non_filter = fc_config.filter_wire == defines.wire_type.green and defines.wire_type.red or defines.wire_type.green,
    }

    -- reconnect the configuration
    for _, cfg in pairs(rewire_cfg) do
        connect_wire(fc_entity, cfg, wire_type)
    end
end

---------------------------------------------------------------------------

--- @param entity_id integer main unit number (== entity id)
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
