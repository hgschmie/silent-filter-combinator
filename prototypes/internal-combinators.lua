-- Copyright 2023 Sil3ntStorm https://github.com/Sil3ntStorm
--
-- Licensed under MS-RL, see https://opensource.org/licenses/MS-RL

local const = require('lib.constants')

local combinator_flags = {
    'placeable-off-grid',
    'not-repairable',
    'not-on-map',
    'not-deconstructable',
    'not-blueprintable',
    'hidden',
    'hide-alt-info',
    'not-flammable',
    'not-upgradable',
    'not-in-kill-statistics',
    'not-in-made-in',
}

---@param source data.CombinatorPrototype
---@param name string
---@return data.CombinatorPrototype combinator
local function create_combinator(source, name)
    local c = table.deepcopy(source) --[[@as data.CombinatorPrototype ]]

    -- PrototypeBase
    c.name = name

    -- CombinatorPrototype
    c.energy_source = { type = 'void' }
    c.active_energy_usage = '0.001W'
    c.sprites = util.empty_sprite(1)
    c.activity_led_sprites = util.empty_sprite(1)
    c.activity_led_light_offsets = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } }
    c.draw_circuit_wires = false

    -- EntityPrototype
    c.allow_copy_paste = false
    c.collision_box = nil
    c.collision_mask = {}
    c.selection_box = nil
    c.flags = combinator_flags
    c.minable = nil
    c.selectable_in_game = false
    return c
end

--------------------------------------------------------------------------------

local dc = create_combinator(data.raw['decider-combinator']['decider-combinator'], const.internal_dc_name) --[[@as data.DeciderCombinatorPrototype ]]
dc.greater_symbol_sprites = util.empty_sprite(1)
dc.greater_or_equal_symbol_sprites = util.empty_sprite(1)
dc.less_symbol_sprites = util.empty_sprite(1)
dc.equal_symbol_sprites = util.empty_sprite(1)
dc.not_equal_symbol_sprites = util.empty_sprite(1)
dc.less_or_equal_symbol_sprites = util.empty_sprite(1)

--------------------------------------------------------------------------------

local ac = create_combinator(data.raw['arithmetic-combinator']['arithmetic-combinator'], const.internal_ac_name) --[[@as data.ArithmeticCombinatorPrototype ]]
ac.plus_symbol_sprites = util.empty_sprite(1)
ac.minus_symbol_sprites = util.empty_sprite(1)
ac.multiply_symbol_sprites = util.empty_sprite(1)
ac.divide_symbol_sprites = util.empty_sprite(1)
ac.modulo_symbol_sprites = util.empty_sprite(1)
ac.power_symbol_sprites = util.empty_sprite(1)
ac.left_shift_symbol_sprites = util.empty_sprite(1)
ac.right_shift_symbol_sprites = util.empty_sprite(1)
ac.and_symbol_sprites = util.empty_sprite(1)
ac.or_symbol_sprites = util.empty_sprite(1)
ac.xor_symbol_sprites = util.empty_sprite(1)

--------------------------------------------------------------------------------

local cc = table.deepcopy(data.raw['constant-combinator']['constant-combinator']) --[[@as data.ConstantCombinatorPrototype]]

-- PrototypeBase
cc.name = const.internal_cc_name

-- ConstantCombinatorPrototype
cc.sprites = util.empty_sprite(1)
cc.activity_led_sprites = util.empty_sprite(1)
cc.activity_led_light_offsets = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } }
cc.draw_circuit_wires = false

-- EntityPrototype
cc.allow_copy_paste = false
cc.collision_box = nil
cc.collision_mask = {}
cc.selection_box = nil
cc.flags = combinator_flags
cc.minable = nil
cc.selectable_in_game = false

data:extend{ac, cc, dc}
