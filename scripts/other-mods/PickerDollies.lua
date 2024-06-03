--------------------------------------------------------------------------------
--
-- PickerDollies support
--
--------------------------------------------------------------------------------

local const = require('lib.constants')
local Is = require('__stdlib__/stdlib/utils/is')

local PickerDolliesSupport = {}

--------------------------------------------------------------------------------

local function picker_dollies_moved(event)
    if not Is.Valid(event.moved_entity) then return end
    if not event.moved_entity.name == const.filter_combinator_name then return end

    This.fico:move(event.start_pos, event.moved_entity)
end

--------------------------------------------------------------------------------

PickerDolliesSupport.runtime = function()
    local Event = require('__stdlib__/stdlib/event/event')

    local picker_dollies_init = function()
        if not remote.interfaces['PickerDollies'] then return end

        if remote.interfaces['PickerDollies']['dolly_moved_entity_id'] then
            Event.on_event(remote.call('PickerDollies', 'dolly_moved_entity_id'), picker_dollies_moved)
        end

        if remote.interfaces['PickerDollies']['add_oblong_name'] then
            remote.call('PickerDollies', 'add_oblong_name', const.filter_combinator_name)
        end
    end

    Event.on_init(picker_dollies_init)
    Event.on_load(picker_dollies_init)
end

return PickerDolliesSupport
