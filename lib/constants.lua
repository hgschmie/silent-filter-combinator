--
-- fully independent, can be loaded into scripts and data
--

local const = {}

--------------------------------------------------------------------------------

const.prefix = 'hps:fc-'
const.name = 'filter-combinator'
const.root = '__filter-combinator-improved__'
const.gfx_location = const.root .. '/graphics/'

---@return FrameworkModConfig config
function const:mod_init()
    return {
        -- prefix is the internal mod prefix
        prefix = const.prefix,
        -- name is a human readable name
        name = const.name,

        root = const.root,
    }
end

---@param value string
---@return string result
function const:with_prefix(value)
    return self.prefix .. value
end

const.gfx_location = '__filter-combinator-improved__/graphics/'

---@param path string
---@return string result
function const:png(path)
    return self.gfx_location .. path .. '.png'
end

---@param id string
---@return string result
function const:locale(id)
    return const:with_prefix('gui.') .. id
end

--------------------------------------------------------------------------------
-- entity names and maps
--------------------------------------------------------------------------------

const.filter_combinator_name = const:with_prefix(const.name)

const.filter_combinator_name_packed = const:with_prefix('filter-combinator-packed')

const.internal_ac_name = const:with_prefix('filter-combinator-ac')
const.internal_cc_name = const:with_prefix('filter-combinator-cc')
const.internal_dc_name = const:with_prefix('filter-combinator-dc')
const.internal_debug_ac_name = const:with_prefix('filter-combinator-debug-ac')
const.internal_debug_cc_name = const:with_prefix('filter-combinator-debug-cc')
const.internal_debug_dc_name = const:with_prefix('filter-combinator-debug-dc')

const.entity_maps = {
    standard = {
        ac = const.internal_ac_name,
        cc = const.internal_cc_name,
        dc = const.internal_dc_name,
    },
    debug = {
        ac = const.internal_debug_ac_name,
        dc = const.internal_debug_dc_name,
        cc = const.internal_debug_cc_name,
    }
}

const.main_entity_names = {
    const.filter_combinator_name,
    const.filter_combinator_name_packed,
}

-- all internal entities
const.internal_entity_names = {
    const.internal_ac_name,
    const.internal_cc_name,
    const.internal_dc_name,
    const.internal_debug_ac_name,
    const.internal_debug_cc_name,
    const.internal_debug_dc_name,
}

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------


const.creation_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_revive
}

const.destruction_events = {
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_entity_died,
    defines.events.script_raised_destroy
}


--------------------------------------------------------------------------------
-- localization
--------------------------------------------------------------------------------

const.fc_entity_name = 'entity-name.' .. const.filter_combinator_name

--------------------------------------------------------------------------------
return const
