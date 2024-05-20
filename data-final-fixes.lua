-- Copyright 2023 Sil3ntStorm https://github.com/Sil3ntStorm
--
-- Licensed under MS-RL, see https://opensource.org/licenses/MS-RL

-- The sole reason for this file to even exist, is other mods misbehaving and doing stupid shit they are not supposed to be doing!

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
    log(string.format('Updated combinators to %d slots because some mod(s) added %d  prototypes AFTER first data stage, which is not supposed to be done!',
                      count, (count - maxCount) + 40));
end
