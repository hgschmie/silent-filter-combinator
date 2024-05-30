if global.fc_data and global.fc_data.VERSION > 3 then return end

global.fc_data.VERSION = 4

require('lib.init')

for idx, fc_entity in pairs(This.fico:entities()) do
    local fc_config = fc_entity.config

    if type(fc_config.enabled) ~= 'boolean' then
        fc_config.enabled = (fc_config.enabled == defines.entity_status.working)
    end

end
