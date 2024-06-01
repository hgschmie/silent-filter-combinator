--------------------------------------------------------------------------------
--
-- There are modules that add items late in the init stage (data-updates).
--
-- So we create a final count of all items at the very latest state of the data initialization.
--
--------------------------------------------------------------------------------


require('lib.init')
local const = require('lib.constants')

-- 20 is a fudge factor to account for some modules adding items in their final-fixes stage
local count = 20;
-- count all existing items, now that every mod should be done adding theirs
for _, info in pairs(data.raw) do
    for _, item in pairs(info) do
        if (item.stack_size or item.type == 'virtual-signal' or item.type == 'fluid') then
            count = count + 1
        end
    end
end

-- round up
count = 10 * math.ceil(count / 10)

data.raw['constant-combinator'][const.internal_cc_name].item_slot_count = count
-- visible cc for debugging with larger slot count
data.raw['constant-combinator'][const.internal_debug_cc_name].item_slot_count = count

--------------------------------------------------------------------------------
require('framework.other-mods').data_final_fixes()
