-- Copyright 2023 Sil3ntStorm https://github.com/Sil3ntStorm
--
-- Licensed under MS-RL, see https://opensource.org/licenses/MS-RL

local cc = table.deepcopy(data.raw['constant-combinator']['constant-combinator'])
cc.name = 'sil-filter-combinator-cc'
cc.icons = {{
    icon = data.raw['constant-combinator']['constant-combinator'].icon,
    tint = {r = 0.682, g = 0, b = 0.682, a = 0.8}
}}
cc.item_slot_count = 200
cc.minable = nil
cc.destructible = false
cc.selectable_in_game = false
cc.flags = {'placeable-off-grid', 'not-repairable', 'not-on-map', 'not-deconstructable', 'not-blueprintable', 'hidden', 'hide-alt-info', 'not-flammable', 'no-copy-paste', 'not-selectable-in-game', 'not-upgradable', 'not-in-kill-statistics', 'not-in-made-in'}
cc.draw_circuit_wires = false
cc.collision_box = nil
cc.selection_box = nil
cc.sprites = util.empty_sprite(1)
cc.collision_mask = {}
cc.activity_led_light_offsets = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } }
cc.activity_led_sprites = util.empty_sprite(1)

data:extend{cc}
