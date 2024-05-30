if global.fc_data and global.fc_data.VERSION > 1 then return end

global.fc_data.VERSION = 2

Player = require('__stdlib__/stdlib/event/player')
Player.init()

