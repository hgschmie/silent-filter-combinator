--------------------------------------------------------------------------------
-- Data setup
--------------------------------------------------------------------------------

require('lib.init')
local const = require('lib.constants')

--------------------------------------------------------------------------------

require('prototypes.internal-combinators')
require('prototypes.filter-combinator')
require('prototypes.style')

--------------------------------------------------------------------------------

local item = table.deepcopy(data.raw.item['arithmetic-combinator']) --[[@as data.ItemPrototype]]
item.name = const.filter_combinator_name
item.place_result = const.filter_combinator_name
item.icon = const:png('filter-combinator-improved')
item.flags = { 'mod-openable' }
item.order = 'c[combinators]-b[filter-combinator-improved]'

local recipe = table.deepcopy(data.raw.recipe['arithmetic-combinator']) --[[@as data.RecipePrototype]]
recipe.name = const.filter_combinator_name
recipe.result = const.filter_combinator_name
recipe.order = item.order

if mods['nullius'] then
    recipe.name = const.filter_combinator_name
    recipe.ingredients = { { 'copper-cable', 5 }, { 'decider-combinator', 2 } }
    recipe.subgroup = 'logistics'
    recipe.category = 'tiny-crafting'
    recipe.order = 'nullius-fa'
end

data:extend { item, recipe }

table.insert(data.raw['technology']['circuit-network'].effects, { type = 'unlock-recipe', recipe = recipe.name })

--------------------------------------------------------------------------------

if mods['nullius'] then
    table.insert(data.raw['technology']['nullius-computation'].effects, { type = 'unlock-recipe', recipe = recipe.name })
end
