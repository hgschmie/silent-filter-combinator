--------------------------------------------------------------------------------
-- Utility functions
--------------------------------------------------------------------------------

local Is = require('__stdlib__/stdlib/utils/is')

---@class FrameworkUtil
--- @field STATUS_TABLE table<defines.entity_status, string>
--- @field STATUS_SPRITES table<defines.entity_status, string>
--- @field STATUS_NAMES table<defines.entity_status, string>
--- @field STATUS_LEDS table<string, string>
local Util = {
    STATUS_LEDS = {},
    STATUS_TABLE = {},
    STATUS_NAMES = {},
    STATUS_SPRITES = {},
}

--------------------------------------------------------------------------------
-- entity_status led and caption
--------------------------------------------------------------------------------

Util.STATUS_LEDS = {
    RED = 'utility/status_not_working',
    GREEN = 'utility/status_working',
    YELLOW = 'utility/status_yellow',
}

Util.STATUS_TABLE = {
    [defines.entity_status.working] = 'GREEN',
    [defines.entity_status.normal] = 'GREEN',
    [defines.entity_status.no_power] = 'RED',
    [defines.entity_status.low_power] = 'YELLOW',
    [defines.entity_status.disabled_by_control_behavior] = 'RED',
    [defines.entity_status.disabled_by_script] = 'RED',
    [defines.entity_status.marked_for_deconstruction] = 'RED',
    [defines.entity_status.disabled] = 'RED',
}

for name, idx in pairs(defines.entity_status) do
    Util.STATUS_NAMES[idx] = 'entity-status.' .. string.gsub(name, '_', '-')
end

for status, led in pairs(Util.STATUS_TABLE) do
    Util.STATUS_SPRITES[status] = Util.STATUS_LEDS[led]
end

--------------------------------------------------------------------------------
-- entity event matcher management
--------------------------------------------------------------------------------

local function create_matcher(values, entity_matcher)
    if not type(values) == 'table' then
        values = { values }
    end

    local matcher_map = {}
    for _, value in pairs(values) do
        matcher_map[value] = true
    end

    return function(event, pattern)
        if not event then return false end
        -- move / clone events
        if event.source and event.destination then
            return matcher_map[entity_matcher(event.source, pattern)] and matcher_map[entity_matcher(event.destination, pattern)]
        end

        return matcher_map[entity_matcher(event.created_entity or event.entity, pattern)]
    end
end

---@param attribute string The entity attribute to match.
---@param values string|string[] One or more values to match.
---@return function(ev: EventData, pattern: any): boolean
function Util.create_event_entity_matcher(attribute, values)
    local matcher = function(entity) return entity and entity[attribute] end
    return create_matcher(values, matcher)
end

---@param values string|string[] One or more names to match to the ghost_name field.
---@return function(ev: EventData, pattern: any): boolean
function Util.create_event_ghost_entity_matcher(values)
    local matcher = function(entity) return entity and entity.type == 'entity-ghost' and entity.ghost_name end
    return create_matcher(values, matcher)
end

--------------------------------------------------------------------------------
-- event registration support (only for runtime!)
--------------------------------------------------------------------------------

if script then
    local Event = require('__stdlib__/stdlib/event/event')

    --- Registers a handler for the given events.
    --- works around https://github.com/Afforess/Factorio-Stdlib/pull/164
    ---@param event_ids defines.events[]
    ---@param handler function(ev: EventData)
    ---@param filter function(ev: EventData, pattern: any?)?:boolean
    ---@param pattern any?
    ---@param options table<string, boolean>?
    function Util.event_register(event_ids, handler, filter, pattern, options)
        assert(Is.Table(event_ids))
        for _, event_id in pairs(event_ids) do
            Event.register(event_id, handler, filter, pattern, options)
        end
    end
end

return Util
