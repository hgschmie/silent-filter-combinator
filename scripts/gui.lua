local flib_gui = require("__flib__/gui-lite")

local const = require('lib.constants')

--- @type FilterCombinatorConfig
local FiCo = require('scripts.filter_combinator')

--- @param player LuaPlayer
local function destroy_gui(player)
    if not global.sil_fc_gui then
        global.sil_fc_gui = {}
    end
    local ui = global.sil_fc_gui[player.index]
    if not ui then
        return
    end
    local main = ui.ui.sil_fc_filter_ui
    if not (main and main.valid) then
        return
    end
    if player.opened == main then
        player.opened = nil
    end
    main.destroy()
end

--- @param event EventData.on_gui_click
local function onWindowClosed(event)
    destroy_gui(game.players[event.player_index])
end

--- @param event EventData.on_gui_switch_state_changed
local function onSwitchEnabled(event)
    local ui = global.sil_fc_gui[event.player_index]
    if not ui then return end

    local data = FiCo.locate_config(ui.unit)
    if not data then return end

    data.config.enabled = event.element.switch_state == "right"
    data.cc.get_or_create_control_behavior().enabled = data.config.enabled
    data.ex.get_or_create_control_behavior().enabled = data.config.enabled
    data.main.active = data.config.enabled
    ui.ui.sil_fc_content.status_flow.status.caption = data.config.enabled and { 'entity-status.working' } or { 'entity-status.disabled' }
    ui.ui.sil_fc_content.status_flow.lamp.sprite = data.config.enabled and 'flib_indicator_green' or 'flib_indicator_red'
    FiCo.add_metatable(data.config):update_entity(data)
end

--- @param event EventData.on_gui_switch_state_changed
local function onSwitchExclusive(event)
    local ui = global.sil_fc_gui[event.player_index]
    if not ui then return end

    local data = FiCo.locate_config(ui.unit)
    if not data then return end

    data.config.exclusive = event.element.switch_state == "right"
    FiCo.add_metatable(data.config):update_entity(data)
end

--- @param event EventData.on_gui_checked_state_changed
local function onSwitchWire(event)
    local ui = global.sil_fc_gui[event.player_index]
    if not ui then return end

    local data = FiCo.locate_config(ui.unit)
    if not data then return end

    if event.element.name == "sil_fc_red_wire" then
        data.config.filter_input_wire = defines.wire_type.red
        ui.ui.sil_fc_content.sil_fc_row2.sil_fc_green_wire.state = not event.element.state
    elseif event.element.name == "sil_fc_green_wire" then
        data.config.filter_input_wire = defines.wire_type.green
        ui.ui.sil_fc_content.sil_fc_row2.sil_fc_red_wire.state = not event.element.state
    else
        return
    end
    FiCo.add_metatable(data.config):update_entity(data)
end

--- @param event  EventData.on_gui_checked_state_changed
local function onToggleWireMode(event)
    local ui = global.sil_fc_gui[event.player_index]
    if not ui then return end

    local data = FiCo.locate_config(ui.unit)
    if not data then return end

    -- ui.ui.sil_fc_content.sil_fc_row2.sil_fc_red_wire.enabled = event.element.state
    -- ui.ui.sil_fc_content.sil_fc_row2.sil_fc_green_wire.enabled = event.element.state
    data.config.filter_input_from_wire = event.element.state
    ui.ui.sil_fc_content.sil_fc_row3.visible = not event.element.state
    FiCo.add_metatable(data.config):update_entity(data)
end

--- @param event EventData.on_gui_elem_changed
local function onSelectSignal(event)
    local ui = global.sil_fc_gui[event.player_index]
    if not ui then return end

    local data = FiCo.locate_config(ui.unit)
    if not data then return end

    if not event.element.tags then return end

    local signal = event.element.elem_value;
    local slot = event.element.tags.idx --[[@as integer]]
    local behavior = data.cc.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    behavior.set_signal(slot, signal and { signal = signal, count = 1 } or nil)
end

flib_gui.add_handlers({
    on_window_closed = onWindowClosed,
    on_switch_enabled = onSwitchEnabled,
    on_switch_exclusive = onSwitchExclusive,
    on_switch_wire = onSwitchWire,
    on_toggle_wire = onToggleWireMode,
    on_select_signal = onSelectSignal,
})

local handler = require("__core__.lualib.event_handler")
handler.add_lib(flib_gui)
flib_gui.handle_events()

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
                         { type = 'choose-elem-button', tags = { idx = i }, style = 'slot_button', elem_type = 'signal', signal = sig.signal, handler = { [defines.events.on_gui_elem_changed] = onSelectSignal } })
        elseif empty_slot_count < settings.startup['sfc-empty-slots'].value or #list % 10 ~= 0 then
            empty_slot_count = empty_slot_count + 1
            table.insert(list,
                         { type = 'choose-elem-button', tags = { idx = i }, style = 'slot_button', elem_type = 'signal', handler = { [defines.events.on_gui_elem_changed] = onSelectSignal } })
        end
    end
    return list
end


--- @param event EventData.on_gui_opened
local function onGuiOpened(event)
    if not (event.entity and event.entity.valid and event.entity.name == const.filter_combinator_name) then
        -- some other GUI was opened, we don't care
        return
    end

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
    --- @type GuiElemDef
    local ui = {
        type = "frame",
        name = "sil_fc_filter_ui",
        direction = "vertical",
        handler = { [defines.events.on_gui_closed] = onWindowClosed },
        { -- Title Bar
            type = "flow",
            style = "flib_titlebar_flow",
            drag_target = "sil_fc_filter_ui",
            {
                type = "label",
                style = "frame_title",
                caption = { const.fc_entity_name },
                drag_target = "sil_fc_filter_ui",
                ignored_by_interaction = true,
            },
            {
                type = "empty-widget",
                style = "flib_titlebar_drag_handle",
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
        }, -- Title Bar End
        {
            type = "frame",
            style = "inside_shallow_frame_with_padding",
            name = "sil_fc_content",
            direction = "vertical",
            {
                type = "flow",
                style = "flib_indicator_flow",
                name = "status_flow",
                {
                    type = "sprite",
                    name = "lamp",
                    style = "flib_indicator",
                    sprite = data.config.enabled and "flib_indicator_green" or "flib_indicator_red",
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
                },
                {
                    type = "label",
                    style = 'label',
                    name = 'id',
                    caption = "ID: " .. data.main.unit_number,
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
                {
                    type = "entity-preview",
                    name = "preview",
                    style = "wide_entity_button",
                },
            },
            { -- Add some spacing
                type = "frame",
                style = "container_invisible_frame_with_title",
            },
            {
                type = "frame",
                style = "container_invisible_frame_with_title",
                {
                    type = "label",
                    style = "heading_3_label",
                    caption = { 'gui-constant.output' },
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
                {
                    type = "label",
                    style = "heading_3_label",
                    caption = { const:locale('mode-heading') },
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
                    name = "sil_fc_red_wire",
                    handler = { [defines.events.on_gui_checked_state_changed] = onSwitchWire },
                },
                {
                    type = "radiobutton",
                    state = data.config.filter_input_wire == defines.wire_type.green,
                    -- enabled = data.config.filter_input_from_wire,
                    caption = { 'item-name.green-wire' },
                    name = "sil_fc_green_wire",
                    handler = { [defines.events.on_gui_checked_state_changed] = onSwitchWire },
                },
            },
            { -- Just so we can hide this entire block in one go
                type = "flow",
                direction = "vertical",
                visible = not data.config.filter_input_from_wire,
                name = "sil_fc_row3",
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
                    {
                        type = "label",
                        style = "heading_3_label",
                        caption = { const:locale('signals-heading') },
                    },
                },
                {
                    type = "scroll-pane",
                    style = "constant_combinator_logistics_scroll_pane",
                    name = "sil_fc_filter_section",
                    {
                        type = "frame",
                        style = "deep_frame_in_shallow_frame",
                        name = "frame",
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
    }
    if not global.sil_fc_gui then
        global.sil_fc_gui = {}
    end
    local created = flib_gui.add(player.gui.screen, ui)
    created.sil_fc_filter_ui.auto_center = true
    created.sil_fc_filter_ui.sil_fc_content.status_flow.spacer.style.horizontally_stretchable = true
    created.sil_fc_content.preview_frame.preview.entity = data.main
    player.opened = created.sil_fc_filter_ui
    global.sil_fc_gui[event.player_index] = { ui = created, unit = event.entity.unit_number }
end

--#endregion


return {
    init = function()
        script.on_event(defines.events.on_gui_opened, onGuiOpened)
    end
}
