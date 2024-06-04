if global.fc_data and global.fc_data.VERSION > 5 then return end

global.fc_data.VERSION = 6

require('lib.init')
local const = require('lib.constants')

local setting = Framework.PREFIX .. 'comb-visible'

if settings['player'][setting] then
    settings['player'][setting] = { value = false }
end

if game then
    for _, player in pairs(game.players) do
        player.mod_settings[setting] = { value = false }
    end
end
