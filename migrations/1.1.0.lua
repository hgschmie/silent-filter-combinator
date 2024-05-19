-- rebuild the global state
-- all combinator unit_numbers in the global.sil_filter_combinators now refer to the unit_number of the main combinator
-- the global.sil_fc_data array is rebuilt to match the main combinator number
-- all invalid settings (main combinator is invalid) are removed
-- the total count of combinators is computed and stored in global.sil_fc_count

local fc_table = {}
local data_table = {}
local count = 0

local function is_valid(entity)
    return entity and entity.valid
end

for _, data in pairs(global.sil_fc_data) do
    local ids = {}

    local register_combinator = function(entity, id)
        assert(entity and entity.valid)
        fc_table[entity.unit_number] = id
        ids[entity.unit_number] = entity
        end


    --- @type FilterCombinatorData
    if data and is_valid(data.main) then
        local id = data.main.unit_number
        assert(id)

        register_combinator(data.main, id)
        register_combinator(data.cc, id)
        register_combinator(data.ex, id)
        for _, e in pairs(data.calc) do
            register_combinator(e, id)
        end

        data_table[id] = data
        data_table[id].ids = ids
        count = count + 1
    end
end

global.sil_filter_combinators = fc_table
global.sil_fc_data = data_table
global.sil_fc_count = count
