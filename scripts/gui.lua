local Events = require('__stdlib__.stdlib.event.event')
local Is = require('__stdlib__.stdlib.utils.is')

local const = require('lib.constants')
local FrameworkGuiManager = Mod.gui_manager


--- @type FilterCombinatorConfig
local FiCo = require('scripts.filter_combinator')

--- @param player LuaPlayer
local function destroy_gui(player)
    if not global.sil_fc_gui then
        global.sil_fc_gui = {}
    end
    local player_ui = global.sil_fc_gui[player.index] --[[@as FrameworkGui ]]
    if not (player_ui and player_ui.ui and player_ui.unit) then return end

    if not Is.Valid(player_ui.ui.root) then return end

    if player.opened == player_ui.ui.root then
        player.opened = nil
    end

    FrameworkGuiManager.destroy_gui(player_ui.ui)
end

--- @param event EventData.on_gui_click
local function onWindowClosed(event)
    destroy_gui(game.players[event.player_index])
end

--- @param event EventData.on_gui_switch_state_changed
local function onSwitchEnabled(event)
    local player_ui = global.sil_fc_gui[event.player_index]
    if not (player_ui and player_ui.ui and player_ui.unit) then return end

    local data = FiCo.locate_config(player_ui.unit)
    if not data then return end

    data.config.enabled = event.element.switch_state == "right"
    data.cc.get_or_create_control_behavior().enabled = data.config.enabled
    data.ex.get_or_create_control_behavior().enabled = data.config.enabled
    data.main.active = data.config.enabled

    local ui_status = player_ui.ui:find_element('status')
    local ui_lamp = player_ui.ui:find_element('lamp')

    ui_status.caption = data.config.enabled and { 'entity-status.working' } or { 'entity-status.disabled' }
    ui_lamp.sprite = data.config.enabled and 'framework_indicator_green' or 'framework_indicator_red'

    FiCo.add_metatable(data.config):update_entity(data)
end

--- @param event EventData.on_gui_switch_state_changed
local function onSwitchExclusive(event)
    local player_ui = global.sil_fc_gui[event.player_index]
    if not (player_ui and player_ui.ui and player_ui.unit) then return end

    local data = FiCo.locate_config(player_ui.unit)
    if not data then return end

    data.config.exclusive = event.element.switch_state == "right"
    FiCo.add_metatable(data.config):update_entity(data)
end

--- @param event EventData.on_gui_checked_state_changed
local function onSwitchWire(event)
    local player_ui = global.sil_fc_gui[event.player_index]
    if not (player_ui and player_ui.ui and player_ui.unit) then return end

    local data = FiCo.locate_config(player_ui.unit)
    if not data then return end

    if event.element.name == player_ui.ui:generate_gui_name('red_wire_indicator') then
        data.config.filter_input_wire = defines.wire_type.red

        local green_wire = player_ui.ui:find_element('green_wire_indicator')
        green_wire.state = not event.element.state
    elseif event.element.name == player_ui.ui:generate_gui_name('green_wire_indicator') then
        data.config.filter_input_wire = defines.wire_type.green

        local red_wire = player_ui.ui:find_element('red_wire_indicator')
        red_wire.state = not event.element.state
    else
        return
    end
    FiCo.add_metatable(data.config):update_entity(data)
end

--- @param event  EventData.on_gui_checked_state_changed
local function onToggleWireMode(event)
    local player_ui = global.sil_fc_gui[event.player_index]
    if not (player_ui and player_ui.ui and player_ui.unit) then return end

    local data = FiCo.locate_config(player_ui.unit)
    if not data then return end

    -- ui.ui.sil_fc_content.sil_fc_row2.sil_fc_red_wire.enabled = event.element.state
    -- ui.ui.sil_fc_content.sil_fc_row2.sil_fc_green_wire.enabled = event.element.state

    data.config.filter_input_from_wire = event.element.state
    local item_grid = player_ui.ui:find_element('item_grid')
    item_grid.visible = not event.element.state

    FiCo.add_metatable(data.config):update_entity(data)
end

--- @param event EventData.on_gui_elem_changed
local function onSelectSignal(event)
    local player_ui = global.sil_fc_gui[event.player_index]
    if not (player_ui and player_ui.ui and player_ui.unit) then return end

    local data = FiCo.locate_config(player_ui.unit)
    if not data then return end

    if not event.element.tags then return end

    local signal = event.element.elem_value
    local slot = event.element.tags.idx --[[@as number]]
    local behavior = data.cc.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    behavior.set_signal(slot, signal and { signal = signal, count = 1 } or nil)
end

--- @param cc LuaEntity
local function make_grid_buttons(cc)
    local behavior = cc.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    local list = {}
    local empty_slot_count = 0
    -- For some reason it always is a table as big as the max signals supported... kinda unexpected but it works out I guess
    for i = 1, behavior.signals_count do
        local sig = behavior.get_signal(i)
        if (sig.signal) then
            table.insert(list,
                         {
                             type = 'choose-elem-button',
                             tags = { idx = i },
                             style = 'slot_button',
                             elem_type = 'signal',
                             signal = sig.signal,
                             handler = { [defines.events.on_gui_elem_changed] = onSelectSignal },
                         })
        elseif empty_slot_count < settings.startup['sfc-empty-slots'].value or #list % 10 ~= 0 then
            empty_slot_count = empty_slot_count + 1
            table.insert(list,
                         {
                             type = 'choose-elem-button',
                             tags = { idx = i },
                             style = 'slot_button',
                             elem_type = 'signal',
                             handler = { [defines.events.on_gui_elem_changed] = onSelectSignal }
                         })
        end
    end
    return list
end


--- @param event EventData.on_gui_opened
local function onGuiOpened(event)
    if not (Is.Valid(event.entity) and event.entity.name == const.filter_combinator_name) then return end

    local data = FiCo.locate_config(event.entity)
    local player = game.players[event.player_index]
    if not data then
        log('Data missing for ' ..
            event.entity.name .. ' on ' .. event.entity.surface.name .. ' at ' .. serpent.line(event.entity.position) .. ' refusing to display UI')
        player.opened = nil
        return
    end

    destroy_gui(player)

    if not (data.cc and data.cc.valid) then
        player.opened = nil
        return
    end

    local slot_buttons = make_grid_buttons(data.cc)
    --- @type FrameworkGuiElemDef
    local ui = {
        type = "frame",
        name = "gui_root",
        direction = "vertical",
        handler = { [defines.events.on_gui_closed] = onWindowClosed },
        elem_mods = { auto_center = true },
        children = {
            { -- Title Bar
                type = "flow",
                style = "framework_titlebar_flow",
                drag_target = "gui_root",
                children = {
                    {
                        type = "label",
                        style = "frame_title",
                        caption = { const.fc_entity_name },
                        drag_target = "gui_root",
                        ignored_by_interaction = true,
                    },
                    {
                        type = "empty-widget",
                        style = "framework_titlebar_drag_handle",
                        ignored_by_interaction = true,
                    },
                    {
                        type = "sprite-button",
                        name = "sil_fc_close_button",
                        style = "frame_action_button",
                        sprite = "utility/close_white",
                        hovered_sprite = "utility/close_black",
                        clicked_sprite = "utility/close_black",
                        mouse_button_filter = { "left" },
                        handler = { [defines.events.on_gui_click] = onWindowClosed },
                    },
                },
            }, -- Title Bar End
            {
                type = "frame",
                style = "inside_shallow_frame_with_padding",
                name = "sil_fc_content",
                direction = "vertical",
                children = {
                    {
                        type = "flow",
                        style = "framework_indicator_flow",
                        name = "status_flow",
                        children = {
                            {
                                type = "sprite",
                                name = "lamp",
                                style = "framework_indicator",
                                sprite = data.config.enabled and "framework_indicator_green" or "framework_indicator_red",
                            },
                            {
                                type = "label",
                                style = "label",
                                name = "status",
                                caption = data.config.enabled and { 'entity-status.working' } or { 'entity-status.disabled' },
                            },
                            {
                                type = "empty-widget",
                                name = "spacer",
                                style_mods = { horizontally_stretchable = true },
                            },
                            {
                                type = "label",
                                style = 'label',
                                name = 'id',
                                caption = "ID: " .. data.main.unit_number,
                            },
                        },
                    },
                    { -- Add some spacing
                        type = "frame",
                        style = "container_invisible_frame_with_title",
                    },
                    {
                        type = "frame",
                        style = "deep_frame_in_shallow_frame",
                        name = "preview_frame",
                        children = {
                            {
                                type = "entity-preview",
                                name = "preview",
                                style = "wide_entity_button",
                                elem_mods = { entity = data.main },
                            },
                        },
                    },
                    { -- Add some spacing
                        type = "frame",
                        style = "container_invisible_frame_with_title",
                    },
                    {
                        type = "frame",
                        style = "container_invisible_frame_with_title",
                        children = {
                            {
                                type = "label",
                                style = "heading_3_label",
                                caption = { 'gui-constant.output' },
                            },
                        },
                    },
                    {
                        type = "switch",
                        switch_state = data.config.enabled and "right" or "left",
                        right_label_caption = { 'gui-constant.on' },
                        left_label_caption = { 'gui-constant.off' },
                        handler = { [defines.events.on_gui_switch_state_changed] = onSwitchEnabled },
                    },
                    { -- Add some spacing
                        type = "frame",
                        style = "container_invisible_frame_with_title",
                    },
                    {
                        type = "frame",
                        style = "container_invisible_frame_with_title",
                        children = {
                            {
                                type = "label",
                                style = "heading_3_label",
                                caption = { const:locale('mode-heading') },
                            },
                        },
                    },
                    {
                        type = "switch",
                        switch_state = data.config.exclusive and "right" or "left",
                        right_label_caption = { const:locale('mode-exclusive') },
                        right_label_tooltip = { const:locale('mode-exclusive-tooltip') },
                        left_label_caption = { const:locale('mode-inclusive') },
                        left_label_tooltip = { const:locale('mode-inclusive-tooltip') },
                        handler = { [defines.events.on_gui_switch_state_changed] = onSwitchExclusive },
                    },
                    { -- Add some spacing
                        type = "frame",
                        style = "container_invisible_frame_with_title",
                    },
                    {
                        type = "flow",
                        name = "sil_fc_row2",
                        direction = "horizontal",
                        children = {
                            {
                                type = "checkbox",
                                caption = { const:locale('mode-wire') },
                                name = "sil_fc_wire_content",
                                state = data.config.filter_input_from_wire,
                                handler = { [defines.events.on_gui_checked_state_changed] = onToggleWireMode },
                            },
                            {
                                type = "radiobutton",
                                state = data.config.filter_input_wire == defines.wire_type.red,
                                -- enabled = data.config.filter_input_from_wire,
                                caption = { 'item-name.red-wire' },
                                name = "red_wire_indicator",
                                handler = { [defines.events.on_gui_checked_state_changed] = onSwitchWire },
                            },
                            {
                                type = "radiobutton",
                                state = data.config.filter_input_wire == defines.wire_type.green,
                                -- enabled = data.config.filter_input_from_wire,
                                caption = { 'item-name.green-wire' },
                                name = "green_wire_indicator",
                                handler = { [defines.events.on_gui_checked_state_changed] = onSwitchWire },
                            },
                        },
                    },
                    { -- Just so we can hide this entire block in one go
                        type = "flow",
                        direction = "vertical",
                        visible = not data.config.filter_input_from_wire,
                        name = "item_grid",
                        children = {
                            { -- Add some spacing
                                type = "frame",
                                style = "container_invisible_frame_with_title",
                            },
                            {
                                type = "line",
                            },
                            {
                                type = "frame",
                                style = "container_invisible_frame_with_title",
                                children = {
                                    {
                                        type = "label",
                                        style = "heading_3_label",
                                        caption = { const:locale('signals-heading') },
                                    },
                                },
                            },
                            {
                                type = "scroll-pane",
                                style = "constant_combinator_logistics_scroll_pane",
                                name = "sil_fc_filter_section",
                                children = {
                                    {
                                        type = "frame",
                                        style = "deep_frame_in_shallow_frame",
                                        name = "frame",
                                        children = {
                                            {
                                                type = "table",
                                                name = "sil_fc_signal_container",
                                                style = 'sil_signal_table',
                                                -- style = "compact_slot_table", -- Best vanilla match, still too wide a gap
                                                -- style = "slot_table", -- No real difference to the compact one?
                                                -- style = "filter_slot_table", -- Correct but has light background instead of dark
                                                -- style = "logistics_slot_table", -- Same as above
                                                -- style = "filter_group_table", -- Kinda weird with dark in between some but not all?
                                                -- style = "inset_frame_container_table", -- Massive gaps
                                                -- style = "logistic_gui_table", -- even worse gaps. No idea where this is ever used
                                                column_count = 10,
                                                children = slot_buttons,
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }

    if not global.sil_fc_gui then
        global.sil_fc_gui = {}
    end
    local gui = FrameworkGuiManager.create_gui(player.gui.screen, ui)
    player.opened = gui.root
    global.sil_fc_gui[event.player_index] = {
        ui = gui,
        unit = event.entity.unit_number,
    }
end

--#endregion


return {
    init = function()
        Events.on_event(defines.events.on_gui_opened, onGuiOpened)
    end,
}
