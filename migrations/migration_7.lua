if global.fc_data and global.fc_data.VERSION > 6 then return end

global.fc_data.VERSION = 7

require('lib.init')
local const = require('lib.constants')

if global.all_signals and global.all_signals.valid then
    global.all_signals.destroy()
end

global.all_signals = nil
global.all_signals_count = nil
