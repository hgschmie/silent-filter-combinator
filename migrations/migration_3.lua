if global.fc_data and global.fc_data.VERSION > 2 then return end

global.fc_data.VERSION = 3

require('lib.init')

for idx, fc_entity in pairs(This.fico:entities()) do
    local fc_config = fc_entity.config

    if type(fc_config.enabled) == 'boolean' then
        fc_config.enabled = fc_config.enabled and defines.entity_status.working or defines.entity_status.disabled
    end

    if fc_config.filter_input_from_wire then
        fc_config.use_wire = fc_config.filter_input_from_wire
        fc_config.filter_input_from_wire = nil
    end

    if fc_config.filter_input_wire then
        fc_config.filter_wire = fc_config.filter_input_wire
        fc_config.filter_input_wire = nil
    end

    if fc_config.exclusive then
        fc_config.include_mode = not fc_config.exclusive
        fc_config.exclusive = nil
    end
end
