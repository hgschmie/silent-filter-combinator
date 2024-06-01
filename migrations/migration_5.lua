if global.fc_data and global.fc_data.VERSION > 4 then return end

global.fc_data.VERSION = 5

require('lib.init')

for _, fc_entity in pairs(This.fico:entities()) do
    fc_entity.ref.input_pos = fc_entity.ref.a3
    fc_entity.ref.input_neg = fc_entity.ref.a1
    fc_entity.ref.filter = fc_entity.ref.ccf
    fc_entity.ref.inp = fc_entity.ref.d1

    fc_entity.ref.a1 = nil
    fc_entity.ref.a3 = nil
    fc_entity.ref.ccf = nil
    fc_entity.ref.d1 = nil
end
