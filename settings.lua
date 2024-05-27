require('lib.init')

data:extend({
      {
         name = Mod.PREFIX .. 'empty-slots',
         type = 'int-setting',
         setting_type = 'startup',
         order = 'a',
         default_value = 20,
         minimum_value = 10,
         maximum_value = 600
      },
      {
         -- Debug mode (framework dependency)
         setting_type = "startup",
         name = Mod.PREFIX .. 'debug-mode',
         type = "bool-setting",
         default_value = false,
         order = "z"
      },
})

--------------------------------------------------------------------------------
require('framework.other-mods').settings()
