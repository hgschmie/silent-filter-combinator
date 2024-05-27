--------------------------------------------------------------------------------
--
-- PickerDollies support 
--
--------------------------------------------------------------------------------

local const = require('lib.constants')

local FiCo = require('scripts.filter_combinator')

local PickerDolliesSupport = {}

--------------------------------------------------------------------------------

local function picker_dollies_moved(event)
    if (not (event.moved_entity and event.moved_entity.valid)) then return end

    if event.moved_entity.name == const.filter_combinator_name then
        FiCo.move_entity(event.moved_entity)
    end
end

--------------------------------------------------------------------------------

PickerDolliesSupport.runtime = function()
    local Event = require('__stdlib__.stdlib.event.event')

    local picker_dollies_init = function()
        if remote.interfaces['PickerDollies'] then
            if remote.interfaces['PickerDollies']['dolly_moved_entity_id'] then
                Event.on_event(remote.call('PickerDollies', 'dolly_moved_entity_id'), picker_dollies_moved)
            end

            if remote.interfaces['PickerDollies']['add_oblong_name'] then
                remote.call('PickerDollies', 'add_oblong_name', const.filter_combinator_name)
            end
        end
    end

    Event.on_init(picker_dollies_init)
    Event.on_load(picker_dollies_init)
end

return PickerDolliesSupport
