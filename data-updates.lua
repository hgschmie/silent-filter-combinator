-- Copyright 2023 Sil3ntStorm https://github.com/Sil3ntStorm
--
-- Licensed under MS-RL, see https://opensource.org/licenses/MS-RL

local const = require('lib.constants')

local maxCount = data.raw["constant-combinator"][const.internal_cc_name].item_slot_count;
-- Initialize to 20 for some safety margin for badly written mods adding items when they should not!
-- All prototypes should already exist when the first data-updates runs!
local count = 20;
-- count all existing items, now that every mod should be done adding theirs
for _, info in pairs(data.raw) do
    for _, item in pairs(info) do
        if (item.stack_size or item.type == 'virtual-signal' or item.type == 'fluid') then
            count = count + 1
        end
    end
end

if (count > maxCount) then
    data.raw["constant-combinator"][const.internal_cc_name].item_slot_count = count;
    log(string.format('Updated internal constant combinators to %d slots', count));
end

if mods['nullius'] then
    data.raw.item[const.filter_combinator_name].localised_name = { const.fc_entity_name }
end
