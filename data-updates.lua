local const = require('lib.constants')

if mods['nullius'] then
    data.raw.item[const.filter_combinator_name].localised_name = { const.fc_entity_name }
end
