require('lib.init')
require('__stdlib__/stdlib/event/player').register_events(true)
local Event = require('__stdlib__/stdlib/event/event')

require('scripts.event-setup')

Event.on_init(function()
    if not global.sil_filter_combinators then
        global.sil_filter_combinators = {}
    end
    if not global.sil_fc_data then
        --- @type FilterCombinatorData[]
        global.sil_fc_data = {}
    end
    global.sil_fc_count = 0
end)

--------------------------------------------------------------------------------
require('framework.other-mods').runtime()
