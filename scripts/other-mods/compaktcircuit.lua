--------------------------------------------------------------------------------
--
-- compaktcircuit support
--
--------------------------------------------------------------------------------

local const = require('lib.constants')

local FiCo = require('scripts.filter_combinator')

local CompaktCircuitSupport = {}

--------------------------------------------------------------------------------

---@param entity LuaEntity
local function ccs_get_info(entity)
    local data = FiCo.locate_config(entity)
    if not data then return end

    local behavior = data.cc.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    return {
        cc_config = data.config,
        cc_params = behavior.parameters,
    }
end

---@param surface LuaSurface
---@param position MapPosition
---@param force LuaForce
local function ccs_create_packed_entity(info, surface, position, force)
    local ent = surface.create_entity { name = const.filter_combinator_name_packed, position = position, force = force, direction = info.direction, raise_built = false }

    if ent then
        local data = FiCo.create_entity(ent)
        data.config = FiCo.add_metatable(info.cc_config)

        local behavior = data.cc.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
        behavior.parameters = info.cc_params
        behavior.enabled = data.config.enabled
        data.ex.get_or_create_control_behavior().enabled = data.config.enabled
        data.config:update_entity(data)
    end
    return ent
end

---@param surface LuaSurface
---@param force LuaForce
local function ccs_create_entity(info, surface, force)
    local ent = surface.create_entity { name = const.filter_combinator_name, position = info.position, force = force, direction = info.direction, raise_built = false }
    if ent then
        local data = FiCo.create_entity(ent)
        data.config = FiCo.add_metatable(info.cc_config)

        local behavior = data.cc.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
        behavior.parameters = info.cc_params
        behavior.enabled = data.config.enabled
        data.ex.get_or_create_control_behavior().enabled = data.config.enabled
        data.config:update_entity(data)
    end
    return ent
end

--------------------------------------------------------------------------------

local function ccs_init()
    if remote.interfaces['compaktcircuit'] and remote.interfaces['compaktcircuit']['add_combinator'] then
        remote.add_interface(const.filter_combinator_name, {
            get_info = ccs_get_info,
            create_packed_entity = ccs_create_packed_entity,
            create_entity = ccs_create_entity,
        })

        remote.call('compaktcircuit', 'add_combinator', {
            name = const.filter_combinator_name,
            packed_names = { const.filter_combinator_name_packed },
            interface_name = const.filter_combinator_name,
        })
    end
end

--------------------------------------------------------------------------------

CompaktCircuitSupport.runtime = function()
    local Event = require('__stdlib__.stdlib.event.event')

    Event.on_init(ccs_init)
    Event.on_load(ccs_init)
end

return CompaktCircuitSupport
