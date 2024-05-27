--------------------------------------------------------------------------------
--
-- nullius support
--
--------------------------------------------------------------------------------

local const = require('lib.constants')

local NulliusSupport = {}

NulliusSupport.data = function()
    table.insert(data.raw['technology']['nullius-computation'].effects, { type = 'unlock-recipe', recipe = const.filter_combinator_name })
end

NulliusSupport.data_updates = function()
    local recipe = data.raw.recipe[const.filter_combinator_name] --[[@as data.RecipePrototype]]
    recipe.ingredients = { { 'copper-cable', 5 }, { 'decider-combinator', 2 } }
    recipe.subgroup = 'logistics'
    recipe.category = 'tiny-crafting'
    recipe.order = 'nullius-fa'

    -- nullius wants to rename this it seems
    data.raw.item[const.filter_combinator_name].localised_name = { const.fc_entity_name }
end

return NulliusSupport
