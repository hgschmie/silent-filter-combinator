--
-- fully independent, can be loaded into scripts and data
--

local const = {}

--------------------------------------------------------------------------------

const.prefix = 'hps:fc-'
const.name = 'filter-combinator'
const.root = '__filter-combinator-improved__'
const.gfx_location = const.root .. '/graphics/'

function const:mod_init()
   return {
      -- prefix is the internal mod prefix
      prefix = const.prefix,
      -- name is a human readable name
      name = const.name,

      root = const.root,

      -- logging tag
      log_tag = '[img=item/' .. const.name .. ']',
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

const.filter_combinator_name = const:with_prefix(const.name)
const.name_prefix_len = #const.filter_combinator_name

const.filter_combinator_name_packed = const:with_prefix('filter-combinator-packed')

const.internal_ac_name = const:with_prefix('filter-combinator-ac')
const.internal_cc_name = const:with_prefix('filter-combinator-cc')
const.internal_dc_name = const:with_prefix('filter-combinator-dc')

-- localization
const.fc_entity_name = 'entity-name.' .. const.filter_combinator_name

return const
