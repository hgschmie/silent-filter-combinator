-- Migration to version 1
if global.fc_data and global.fc_data.VERSION > 0 then return end

global.fc_data = {
    VERSION = 1,
}

local fc = {}

assert(global.sil_filter_combinators)
assert(global.sil_fc_data)
assert(global.sil_fc_count)

local count = 0
for id, config in pairs(global.sil_fc_data) do

    local cc_behavior = config.cc.get_or_create_control_behavior()

    ---@type ConstantCombinatorParameters[]
    local signals = {}

    for _, signal in pairs(cc_behavior.parameters) do
        if signal.signal.name then
            table.insert(signals, signal)
        end
    end

    --- @type FilterCombinatorData
    local fc_entity = {
        main = config.main,
        --- @type FilterCombinatorConfig
        config = {
            enabled = config.config.enabled or true, -- enabled status of the fc
            use_wire = config.config.filter_input_from_wire or false,
            filter_wire = config.config.filter_input_wire or defines.wire_type.red,
            include_mode = not (config.config.exclusive or false),
            signals = signals,
        },
        entities = config.ids,
        ref = {
            main = config.main,

            cc = config.cc,
            ex = config.ex,

            ccf = config.calc[9],

            out = config.calc[10],
            inv = config.inv,

            a1 = config.calc[5],
            a2 = config.calc[6],
            a3 = config.calc[7],
            a4 = config.calc[8],

            d1 = config.calc[1],
            d2 = config.calc[2],
            d3 = config.calc[3],
            d4 = config.calc[4],
        },
    }

    fc[id] = fc_entity
    count = count + 1
end

global.fc_data.fc = fc
global.fc_data.count = count

assert(count == global.sil_fc_count)

global.sil_filter_combinators = nil
global.sil_fc_data = nil
global.sil_fc_count = nil
global.sil_fc_gui = nil
global.sil_fc_slot_error_logged = nil
