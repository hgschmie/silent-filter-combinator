-- Copyright 2023 Sil3ntStorm https://github.com/Sil3ntStorm
--
-- Licensed under MS-RL, see https://opensource.org/licenses/MS-RL

local const = require('lib.constants')

local function update_sprite(sprite, filename, x, y)
    sprite.filename = const:png(filename)
    sprite.x = x or 0
    sprite.y = y or 0
end

local fc = table.deepcopy(data.raw['arithmetic-combinator']['arithmetic-combinator']) --[[@as data.ArithmeticCombinatorPrototype ]]

local sprite_h = table.deepcopy(fc.and_symbol_sprites.north)
update_sprite(sprite_h, 'filter-combinator-display')
update_sprite(sprite_h.hr_version, 'hr-filter-combinator-improved-display')

local sprite_v = table.deepcopy(fc.and_symbol_sprites.east)
update_sprite(sprite_v, 'filter-combinator-display')
update_sprite(sprite_v.hr_version, 'hr-filter-combinator-improved-display')

local full_sprite = { east = sprite_v, west = sprite_v, north = sprite_h, south = sprite_h }

-- PrototypeBase
fc.name = const.filter_combinator_name

-- ArithmeticCombinatorPrototype
fc.plus_symbol_sprites = full_sprite
fc.minus_symbol_sprites = full_sprite
fc.multiply_symbol_sprites = full_sprite
fc.divide_symbol_sprites = full_sprite
fc.modulo_symbol_sprites = full_sprite
fc.power_symbol_sprites = full_sprite
fc.left_shift_symbol_sprites = full_sprite
fc.right_shift_symbol_sprites = full_sprite
fc.and_symbol_sprites = full_sprite
fc.or_symbol_sprites = full_sprite
fc.xor_symbol_sprites = full_sprite

-- EntityPrototype
fc.icon = const:png('filter-combinator-improved')
fc.minable.result = fc.name

data:extend { fc }

--------------------------------------------------------------------------------

if mods['compaktcircuit'] then
    local packed = table.deepcopy(fc)

    -- PrototypeBase
    packed.name = const.filter_combinator_name_packed

    -- ArithmeticCombinatorPrototype
    packed.plus_symbol_sprites = util.empty_sprite(1)
    packed.minus_symbol_sprites = util.empty_sprite(1)
    packed.multiply_symbol_sprites = util.empty_sprite(1)
    packed.divide_symbol_sprites = util.empty_sprite(1)
    packed.modulo_symbol_sprites = util.empty_sprite(1)
    packed.power_symbol_sprites = util.empty_sprite(1)
    packed.left_shift_symbol_sprites = util.empty_sprite(1)
    packed.right_shift_symbol_sprites = util.empty_sprite(1)
    packed.and_symbol_sprites = util.empty_sprite(1)
    packed.or_symbol_sprites = util.empty_sprite(1)
    packed.xor_symbol_sprites = util.empty_sprite(1)

    -- CombinatorPrototype
    packed.sprites = util.empty_sprite(1)
    packed.activity_led_light_offsets = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } }
    packed.activity_led_sprites = util.empty_sprite(1)
    packed.draw_circuit_wires = false

    -- turn off the flashing icons
    packed.energy_source.render_no_network_icon = false
    packed.energy_source.render_no_power_icon = false

    -- EntityPrototype
    packed.collision_box = nil
    packed.collision_mask = {}
    packed.selection_box = nil
    packed.flags = { 'placeable-off-grid', 'not-repairable', 'not-on-map', 'not-deconstructable', 'not-blueprintable', 'hidden', 'hide-alt-info', 'not-flammable',
        'no-copy-paste', 'not-selectable-in-game', 'not-upgradable', 'not-in-kill-statistics', 'not-in-made-in' }
    packed.minable = nil
    packed.selectable_in_game = false

    data:extend { packed }
end
