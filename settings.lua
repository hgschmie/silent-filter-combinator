local const = require('lib.constants')

data:extend({
    {
        name = const:with_prefix('empty-slots'),
        type = 'int-setting',
        setting_type = 'startup',
        order = 'a',
        default_value = 20,
        minimum_value = 10,
        maximum_value = 600
    },
})
