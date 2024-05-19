-- Copyright 2023 Sil3ntStorm https://github.com/Sil3ntStorm
--
-- Licensed under MS-RL, see https://opensource.org/licenses/MS-RL

local empty_sprite_4way = { north = util.empty_sprite(1), south = util.empty_sprite(1), east = util.empty_sprite(1), west = util.empty_sprite(1)}

local function create_combinator(source, name)
    local c = table.deepcopy(source)
    c.name = name
    c.minable = nil
    c.destructible = false
    c.selectable_in_game = false
    c.flags = {'placeable-off-grid', 'not-repairable', 'not-on-map', 'not-deconstructable', 'not-blueprintable', 'hidden', 'hide-alt-info', 'not-flammable', 'no-copy-paste', 'not-selectable-in-game', 'not-upgradable', 'not-in-kill-statistics', 'not-in-made-in'}
    c.draw_circuit_wires = false
    c.collision_box = nil
    c.selection_box = nil
    c.collision_mask = {}
    c.sprites = util.empty_sprite(1)
    c.energy_source = { type = 'void' }
    c.active_energy_usage = '0.001W'
    c.activity_led_light_offsets = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } }
    c.activity_led_sprites = util.empty_sprite(1)
    return c
end

local dc = create_combinator(data.raw['decider-combinator']['decider-combinator'], 'sil-filter-combinator-dc')
dc.greater_symbol_sprites = empty_sprite_4way
dc.greater_or_equal_symbol_sprites = empty_sprite_4way
dc.less_symbol_sprites = empty_sprite_4way
dc.equal_symbol_sprites = empty_sprite_4way
dc.not_equal_symbol_sprites = empty_sprite_4way
dc.less_or_equal_symbol_sprites = empty_sprite_4way

data:extend{dc}

local ac = create_combinator(data.raw['arithmetic-combinator']['arithmetic-combinator'], 'sil-filter-combinator-ac')
ac.plus_symbol_sprites = empty_sprite_4way
ac.minus_symbol_sprites = empty_sprite_4way
ac.multiply_symbol_sprites = empty_sprite_4way
ac.divide_symbol_sprites = empty_sprite_4way
ac.modulo_symbol_sprites = empty_sprite_4way
ac.power_symbol_sprites = empty_sprite_4way
ac.left_shift_symbol_sprites = empty_sprite_4way
ac.right_shift_symbol_sprites = empty_sprite_4way
ac.and_symbol_sprites = empty_sprite_4way
ac.or_symbol_sprites = empty_sprite_4way
ac.xor_symbol_sprites = empty_sprite_4way

data:extend{ac}
